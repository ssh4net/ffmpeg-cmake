#include <stdio.h>

#include <libavcodec/avcodec.h>
#include <libavdevice/avdevice.h>
#include <libavfilter/avfilter.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>

static int check_version(const char *name, unsigned version)
{
    printf("%s=%u\n", name, version);
    return version != 0 ? 0 : 1;
}

int main(void)
{
#if defined(FFMPEG_CONSUMER_AGGREGATE)
    return check_version("libavutil", avutil_version()) ||
           check_version("libswresample", swresample_version()) ||
           check_version("libswscale", swscale_version()) ||
           check_version("libavcodec", avcodec_version()) ||
           check_version("libavformat", avformat_version()) ||
           check_version("libavfilter", avfilter_version()) ||
           check_version("libavdevice", avdevice_version());
#elif defined(FFMPEG_CONSUMER_AVUTIL)
    return check_version("libavutil", avutil_version());
#elif defined(FFMPEG_CONSUMER_SWRESAMPLE)
    return check_version("libswresample", swresample_version());
#elif defined(FFMPEG_CONSUMER_SWSCALE)
    return check_version("libswscale", swscale_version());
#elif defined(FFMPEG_CONSUMER_AVCODEC)
    return check_version("libavcodec", avcodec_version());
#elif defined(FFMPEG_CONSUMER_AVFORMAT)
    return check_version("libavformat", avformat_version());
#elif defined(FFMPEG_CONSUMER_AVFILTER)
    return check_version("libavfilter", avfilter_version());
#elif defined(FFMPEG_CONSUMER_AVDEVICE)
    return check_version("libavdevice", avdevice_version());
#else
#   error Missing consumer smoke test selector.
#endif
}
