use chrono::Local;
use opencv::{
    core::{Size, Mat, absdiff, Point, Scalar, Vector, BORDER_DEFAULT},
    imgproc::{blur, cvt_color, dilate, threshold, COLOR_BGR2GRAY, THRESH_BINARY, get_structuring_element, MORPH_RECT},
    prelude::*,
    videoio::{VideoCapture, VideoWriter, CAP_ANY},
    highgui,
};
use reqwest::multipart;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use tokio::time;

const SERVER_URL: &str = "http://localhost:3000/api/upload";
const MOTION_THRESHOLD: f64 = 30.0;
const MIN_CONTOUR_AREA: f64 = 500.0;
const POST_RECORD_SECONDS: u64 = 5;

#[tokio::main]
async fn main() -> opencv::Result<()> {
    println!("Starting Edge Agent...");

    // Initialize camera (0 is usually the default USB/built-in webcam)
    let mut cam = VideoCapture::new(0, CAP_ANY)?;
    if !cam.is_opened()? {
        panic!("Unable to open camera!");
    }

    let frame_width = cam.get(opencv::videoio::CAP_PROP_FRAME_WIDTH)? as i32;
    let frame_height = cam.get(opencv::videoio::CAP_PROP_FRAME_HEIGHT)? as i32;
    let fps = cam.get(opencv::videoio::CAP_PROP_FPS)?;
    let fps = if fps > 0.0 { fps } else { 30.0 };

    println!("Camera initialized: {}x{} @ {}fps", frame_width, frame_height, fps);

    let mut prev_frame = Mat::default();
    
    let mut is_recording = false;
    let mut last_motion_time = Instant::now();
    let mut video_writer: Option<VideoWriter> = None;
    let mut current_filename = String::new();

    let client = reqwest::Client::new();

    loop {
        let mut frame = Mat::default();
        if !cam.read(&mut frame)? || frame.empty() {
            eprintln!("Failed to grab frame");
            break;
        }

        let mut gray = Mat::default();
        cvt_color(&frame, &mut gray, COLOR_BGR2GRAY, 0)?;
        blur(&gray.clone(), &mut gray, Size::new(21, 21), Point::new(-1, -1), BORDER_DEFAULT)?;

        if prev_frame.empty() {
            prev_frame = gray.clone();
            continue;
        }

        let mut frame_delta = Mat::default();
        absdiff(&prev_frame, &gray, &mut frame_delta)?;
        
        let mut thresh = Mat::default();
        threshold(&frame_delta, &mut thresh, MOTION_THRESHOLD, 255.0, THRESH_BINARY)?;
        
        // Dilate to fill in holes
        let mut dilated = Mat::default();
        let kernel = get_structuring_element(MORPH_RECT, Size::new(5, 5), Point::new(-1, -1))?;
        dilate(&thresh, &mut dilated, &kernel, Point::new(-1, -1), 2, BORDER_DEFAULT, Scalar::default())?;

        let mut contours = Vector::<Vector<Point>>::new();
        opencv::imgproc::find_contours(&dilated, &mut contours, opencv::imgproc::RETR_EXTERNAL, opencv::imgproc::CHAIN_APPROX_SIMPLE, Point::new(0,0))?;

        let mut motion_detected = false;
        for contour in contours.iter() {
            if opencv::imgproc::contour_area(&contour, false)? > MIN_CONTOUR_AREA {
                motion_detected = true;
                break;
            }
        }

        prev_frame = gray.clone();

        if motion_detected {
            last_motion_time = Instant::now();
            if !is_recording {
                is_recording = true;
                current_filename = format!("event_{}.mp4", Local::now().format("%Y%m%d_%H%M%S"));
                println!("Motion detected! Starting recording: {}", current_filename);
                
                // Use mp4v or avc1 for MP4
                let fourcc = opencv::videoio::VideoWriter::fourcc('m' as i8, 'p' as i8, '4' as i8, 'v' as i8)?;
                let mut writer = VideoWriter::new(
                    &current_filename,
                    fourcc,
                    fps,
                    Size::new(frame_width, frame_height),
                    true
                )?;
                video_writer = Some(writer);
            }
        }

        if is_recording {
            if let Some(writer) = video_writer.as_mut() {
                writer.write(&frame)?;
            }

            // Stop recording if no motion for POST_RECORD_SECONDS
            if last_motion_time.elapsed().as_secs() > POST_RECORD_SECONDS {
                println!("No motion for {}s. Stopping recording.", POST_RECORD_SECONDS);
                is_recording = false;
                video_writer = None; // Drop writer to close file

                // Upload the file
                let file_to_upload = current_filename.clone();
                let client_clone = client.clone();
                
                tokio::spawn(async move {
                    println!("Uploading {}...", file_to_upload);
                    match tokio::fs::read(&file_to_upload).await {
                        Ok(file_data) => {
                            let part = multipart::Part::bytes(file_data)
                                .file_name(file_to_upload.clone())
                                .mime_str("video/mp4").unwrap();
                            let form = multipart::Form::new().part("video", part);
                            
                            match client_clone.post(SERVER_URL).multipart(form).send().await {
                                Ok(res) => {
                                    if res.status().is_success() {
                                        println!("Upload successful! Deleting local file.");
                                        let _ = tokio::fs::remove_file(&file_to_upload).await;
                                    } else {
                                        eprintln!("Upload failed: {:?}", res.status());
                                    }
                                }
                                Err(e) => eprintln!("Upload error: {}", e),
                            }
                        }
                        Err(e) => eprintln!("Failed to read file for upload: {}", e),
                    }
                });
            }
        }

        // Optional: show preview
        highgui::imshow("Edge Agent - Live View", &frame)?;
        if highgui::wait_key(1)? == 113 { // 'q' to quit
            break;
        }
    }

    Ok(())
}
