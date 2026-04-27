#include <libavutil/version.h>
#include <libswresample/swresample.h>

int main(void)
{
    return avutil_version() != 0 && swresample_version() != 0 ? 0 : 1;
}

