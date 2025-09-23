/************************************************************
 * host-forth
 * PC part for three-instruction Forth
 * 2025 YRabbit
 ************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <termios.h>
#include <time.h>

#include <ficl.h>

/** Monitor commands */
uint8_t const ReadByte  = 0x24U;
uint8_t const WriteByte = 0x38U;
uint8_t const CallAddr  = 0x8U;

/** sleep for msec miliseconds
 *
 * @param msec - number of miliseconds
 * */
int msleep(long msec)
{
    struct timespec ts;
    int res;

    if (msec < 0)
    {
        errno = EINVAL;
        return -1;
    }

    ts.tv_sec = msec / 1000;
    ts.tv_nsec = (msec % 1000) * 1000000;

    do {
        res = nanosleep(&ts, &ts);
    } while (res && errno == EINTR);

    return res;
}

/** Read a command line arguments
 *
 * @param argc - argument's count (from main)
 * @param argv - argument array (from main)
 * @param baudrate_str - port speed
 * @param device_str - port device
 * */
void parse_args(int argc, char *argv[], char *baudrate_str, char *device_str) {
    while (1) {
        int opt = getopt(argc, argv, "b:d:h");
        if (opt == -1) {
            break;
        }

        switch (opt) {
            case 'b':
                baudrate_str = optarg;
                break;
            case 'd':
                device_str = optarg;
                break;
            case 'h':
                printf("Usage: %s [-b baudrate] [-d device] filename\n", argv[0]);
                printf("-b: baudrate (default 115200)\n");
                printf("-d: device (default /dev/ttyU1)\n");
                printf("filename: input file\n\n");
                printf("Example:\n");
                printf("  %s -b 115200 -d /dev/ttyUSB0 input.f\n", argv[0]);
                printf("  %s input.f\n", argv[0]);
                printf("  %s -d /dev/ttyS0 input.f\n", argv[0]);
                exit(0);
            default:
                printf("Invalid option: %s\n", argv[optind - 1]);
                printf("Use -h for help.\n");
                exit(1);
        }
    }
}

//////////////////////////////////////
/// Port functions
//////////////////////////////////////
static int port_fd = -1; ///< Port file descriptor

/** Open port
 *
 * @param device - port device
 * @param baudrate - port baudrate
 * @returns port file descriptor
 * */
int open_port(char const *device, int baudrate) {
    port_fd = open(device, O_RDWR | O_NOCTTY | O_NDELAY);
    if (port_fd == -1) {
        perror("Unable to open port - ");
        return(port_fd);
    }
    fcntl(port_fd, F_SETFL, 0);

    struct termios options;
    tcgetattr(port_fd, &options);
    cfsetispeed(&options, B115200);
    cfsetospeed(&options, B115200);
    options.c_cflag |= (CLOCAL | CREAD);

    options.c_cflag &= ~CSIZE; /* Mask the character size bits */
    options.c_cflag |= CS8;    /* Select 8 data bits */
    options.c_cflag &= ~PARENB;
    options.c_cflag &= ~CSTOPB;
    options.c_oflag &= ~OPOST;
    options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);

    tcsetattr(port_fd, TCSANOW, &options);
    return(port_fd);
}

/** Close port */
void close_port(void) {
    close(port_fd);
}

//////////////////////////////////////
/// 3 Forth primitives
//////////////////////////////////////
/// xc@ ( a -- c )
static void xc_at(ficlVm *vm) {
    // send address in reverse order: MSB first
    uint32_t addr = ficlStackPopUnsigned(vm->dataStack);
    uint8_t buf;

    buf = addr >> 8;
    write(port_fd, &buf, 1);
    buf = addr;
    write(port_fd, &buf, 1);

    // command byte
    write(port_fd, &ReadByte, 1);

    read(port_fd, &buf, 1);
    ficlStackPushUnsigned(vm->dataStack, buf);
}

/// xc! ( c a -- )
static void xc_store(ficlVm *vm) {
    // send address in reverse order: MSB first
    uint32_t addr = ficlStackPopUnsigned(vm->dataStack);
    uint8_t buf;

    buf = addr >> 8;
    write(port_fd, &buf, 1);
    buf = addr;
    write(port_fd, &buf, 1);

    // command byte
    write(port_fd, &WriteByte, 1);

    // send byte
    buf = ficlStackPopUnsigned(vm->dataStack);
    write(port_fd, &buf, 1);
}

/// xcall ( a -- )
static void xc_call(ficlVm *vm) {
    // send address in reverse order: MSB first
    uint32_t addr = ficlStackPopUnsigned(vm->dataStack);
    uint8_t buf;

    buf = addr >> 8;
    write(port_fd, &buf, 1);
    buf = addr;
    write(port_fd, &buf, 1);

    // command byte
    write(port_fd, &CallAddr, 1);

}

//////////////////////////////////////
int main(int argc, char *argv[]) {
    char *baudrate_str = NULL;
    char *device_str = NULL;
    char *filename = NULL;
    int baudrate = 115200;
    char device[256] = "/dev/ttyU1";

    parse_args(argc, argv, baudrate_str, device_str);

    if (optind < argc) {
        filename = argv[optind];
    } else {
        filename = NULL;
    }

    // If baudrate_str was not provided, use default baudrate
    if (!baudrate_str) {
        printf("Using default baudrate: %d\n", baudrate);
    }

    // If device_str was not provided, use default device
    if (!device_str) {
        printf("Using default device: %s\n", device);
    } else {
        strncpy(device, device_str, sizeof(device));
    }

    // serial port
    if (open_port(device, baudrate) < 0) {
        return(1);
    }

    ficlSystem* sys = ficlSystemCreate(NULL);
    ficlDictionary*dict = ficlSystemGetDictionary(sys);
    ficlDictionarySetPrimitive(dict, "xc@", xc_at, FICL_WORD_DEFAULT);
    ficlDictionarySetPrimitive(dict, "xc!", xc_store, FICL_WORD_DEFAULT);
    ficlDictionarySetPrimitive(dict, "xcall", xc_call, FICL_WORD_DEFAULT);
    ficlVm* vm = ficlSystemCreateVm(sys);

    char buf[256];
    ficlString forth_string;
    if (filename) {
        ficlCell sid;
        sid.i = 1;
        vm->sourceId = sid;
        FILE *f = fopen(filename, "rt");
        while (!feof(f)) {
            fgets(buf, sizeof(buf) - 1, f);
            FICL_STRING_SET_FROM_CSTRING(forth_string, buf);
            ficlVmExecuteString(vm, forth_string);
        }
        fclose(f);
    }

    ficlCell sid;
    sid.i = 0;
    vm->sourceId = sid;

    printf("ok> ");
    while (1) {
        gets_s(buf, sizeof(buf) - 1);
        FICL_STRING_SET_FROM_CSTRING(forth_string, buf);
        if (FICL_VM_STATUS_USER_EXIT == ficlVmExecuteString(vm, forth_string)) {
            break;
        }
    }

    ficlSystemDestroy(sys);

    close_port();
    return(0);
}

// vim: set et sw=4 ts=4:
