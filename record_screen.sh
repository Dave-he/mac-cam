#!/bin/bash

# iMac屏幕录制脚本，自动保存为mp4格式，同时录制摄像头画面

# 默认参数
OUTPUT_DIR="$HOME/Movies/Videos"
DEFAULT_FILENAME="screen_record_$(date +%Y%m%d_%H%M%S).mp4"
RECORD_TIME=""  # 空表示无限录制，直到手动停止
CAMERA_INPUT="0"  # 默认摄像头输入设备

# 显示帮助信息
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -o, --output <filename>    指定输出文件名 (默认: $DEFAULT_FILENAME)"
    echo "  -d, --duration <seconds>   指定录制时长 (默认: 无限)"
    echo "  -h, --help                 显示此帮助信息"
    echo ""
    echo "Example:"
    echo "  $0 -o my_recording.mp4 -d 60  # 录制60秒，保存为my_recording.mp4"
    echo ""
    echo "To stop recording, press Ctrl+C"
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -d|--duration)
            RECORD_TIME="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown parameter: $1"
            show_help
            exit 1
            ;;
    esac
done

# 设置输出文件
if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="$OUTPUT_DIR/$DEFAULT_FILENAME"
else
    # 如果没有指定目录，使用默认目录
    if [[ "$OUTPUT_FILE" != /* ]]; then
        OUTPUT_FILE="$OUTPUT_DIR/$OUTPUT_FILE"
    fi
fi

# 确保输出目录存在
mkdir -p "$OUTPUT_DIR"

echo "开始录制屏幕..."
echo "输出文件: $OUTPUT_FILE"
if [ -n "$RECORD_TIME" ]; then
    echo "录制时长: $RECORD_TIME 秒"
fi
echo "按 Ctrl+C 停止录制"

# 构建ffmpeg命令，同时录制屏幕和摄像头
# 使用两个独立的输入，然后通过滤镜合并
FFMPEG_CMD="ffmpeg -y \
-f avfoundation -i \"1\" \
-f avfoundation -i \"0\" \
-filter_complex \"[1:v]scale=320:240[cam];[0:v][cam]overlay=main_w-overlay_w-20:main_h-overlay_h-20\" \
-pix_fmt yuv420p -c:v libx264 -preset medium -crf 23"

# 添加录制时长参数
if [ -n "$RECORD_TIME" ]; then
    FFMPEG_CMD="$FFMPEG_CMD -t $RECORD_TIME"
fi

# 添加输出文件
FFMPEG_CMD="$FFMPEG_CMD \"$OUTPUT_FILE\""

# 执行录制命令
eval $FFMPEG_CMD

echo "录制完成！文件已保存到: $OUTPUT_FILE"