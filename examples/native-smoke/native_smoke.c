#include <libavcodec/avcodec.h>
#include <libavdevice/avdevice.h>
#include <libavfilter/avfilter.h>
#include <libavformat/avformat.h>
#include <libavutil/version.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>

int main(void)
{
    const int ok = avcodec_version() != 0 &&
                   avdevice_version() != 0 &&
                   avfilter_version() != 0 &&
                   avformat_version() != 0 &&
                   avutil_version() != 0 &&
                   swresample_version() != 0 &&
                   swscale_version() != 0;
    return ok ? 0 : 1;
}
