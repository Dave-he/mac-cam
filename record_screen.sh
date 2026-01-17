#!/bin/bash

# iMac屏幕录制脚本，自动保存为mp4格式，同时录制摄像头画面

# 默认参数
OUTPUT_DIR="$HOME/Movies/Videos"
DEFAULT_FILENAME="screen_record_$(date +%Y%m%d_%H%M%S)"
RECORD_TIME=""  # 空表示无限录制，直到手动停止
SEGMENT_TIME="600"  # 默认分段时长，单位秒（10分钟）
CAMERA_INPUT="0"  # 默认摄像头输入设备

# 显示帮助信息
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -o, --output <filename>    指定输出文件名前缀 (默认: $DEFAULT_FILENAME)"
    echo "  -d, --duration <seconds>   指定总录制时长 (默认: 无限)"
    echo "  -s, --segment <seconds>    指定分段时长 (默认: $SEGMENT_TIME秒，即10分钟)"
    echo "  -h, --help                 显示此帮助信息"
    echo ""
    echo "Examples:"
    echo "  $0 -o my_recording -d 3600 -s 600  # 录制1小时，每10分钟保存一段"
    echo "  $0 -s 300                          # 无限录制，每5分钟保存一段"
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
        -s|--segment)
            SEGMENT_TIME="$2"
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

# 设置输出文件前缀
if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE_PREFIX="$OUTPUT_DIR/$DEFAULT_FILENAME"
else
    # 如果没有指定目录，使用默认目录
    if [[ "$OUTPUT_FILE" != /* ]]; then
        OUTPUT_FILE_PREFIX="$OUTPUT_DIR/$OUTPUT_FILE"
    else
        OUTPUT_FILE_PREFIX="$OUTPUT_FILE"
    fi
fi

# 确保输出目录存在
mkdir -p "$OUTPUT_DIR"

echo "开始录制屏幕..."
echo "输出文件前缀: $OUTPUT_FILE_PREFIX"
echo "分段时长: $SEGMENT_TIME 秒"
if [ -n "$RECORD_TIME" ]; then
    echo "总录制时长: $RECORD_TIME 秒"
fi
echo "按 Ctrl+C 停止录制"

# 构建ffmpeg命令，同时录制屏幕和摄像头，支持分段录制
# 使用两个独立的输入，然后通过滤镜合并
# -f segment 用于分段录制，-segment_time 设置分段时长
FFMPEG_CMD="ffmpeg -y \
-f avfoundation -i \"1\" \
-f avfoundation -i \"0\" \
-filter_complex \"[1:v]scale=320:240[cam];[0:v][cam]overlay=main_w-overlay_w-20:main_h-overlay_h-20\" \
-pix_fmt yuv420p -c:v libx264 -preset medium -crf 23 \
-f segment -segment_time $SEGMENT_TIME -segment_format mp4 -reset_timestamps 1"

# 添加录制时长参数
if [ -n "$RECORD_TIME" ]; then
    FFMPEG_CMD="$FFMPEG_CMD -t $RECORD_TIME"
fi

# 添加输出文件模式，使用%03d作为分段编号
FFMPEG_CMD="$FFMPEG_CMD \"${OUTPUT_FILE_PREFIX}_%03d.mp4\""

# 执行录制命令
eval $FFMPEG_CMD

echo "录制完成！文件已保存到: $OUTPUT_FILE_PREFIX_*.mp4"