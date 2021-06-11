#!/usr/bin/python
import guest_tools as GT
import libvirt
import argparse

from time import sleep
from datetime import datetime as dt

PATH_TAR = "C:/Windows/System32/tar.exe"
PATH_TARGZ = "C:/Temp/benchmark-{}.tar.gz".format(
    dt.now().strftime('%Y-%m-%d-%H-%M-%S'))
PATH_DOWNLOAD = "/tmp/benchmark-{}.tar.gz".format(
    dt.now().strftime('%Y-%m-%d-%H-%M-%S'))
PATH_BENCH_RESULT = "C:/Users/Gamer/Documents/Rockstar Games/GTA V/Benchmarks"
COMMAND_ERASE = "Remove-Item -Path 'C:/Users/Gamer/Documents/Rockstar Games/"
"GTA V/Benchmarks/' -Recurse -Force"


def main(args):
    conn = None
    while True:
        try:
            conn = libvirt.open('qemu:///system')
        except Exception:
            pass
        if not conn:
            print ('Waiting for libvirt...')
            sleep(3)
        else:
            print("Connected to libvirt")
            break

    domain = conn.lookupByName(args.vm)
    print("Downloading GTA V Benchmark results from {}".format(args.vm))
    pid = GT.guest_exec(
        domain, PATH_TAR,
        ["-cvzf", PATH_TARGZ, "-C", PATH_BENCH_RESULT, "*.txt"])
    if pid:
        response = GT.guest_exec_get_response(domain, pid)
        print(response)

    GT.guest_download_file(domain, PATH_TARGZ, PATH_DOWNLOAD)

    print("Erasing GTA V Benchmark results from {}".format(args.vm))
    pid = GT.guest_exec(
        domain, "powershell.exe", ["-Command", COMMAND_ERASE])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='PlayKey GTA V Benchmark Result Downloader')
    parser.add_argument('--vm', type=str, action='store', dest='vm', help='VM')
    args = parser.parse_args()
    main(args)
