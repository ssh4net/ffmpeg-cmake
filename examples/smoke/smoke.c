#include <stdio.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>

int main(void)
{
    const AVCodec *codec = avcodec_find_decoder(AV_CODEC_ID_H264);
    unsigned version = avformat_version();

    printf("libavformat=%u libavutil=%s h264_decoder=%s\n",
           version,
           av_version_info(),
           codec != NULL ? "yes" : "no");

    return version == 0 ? 1 : 0;
}

