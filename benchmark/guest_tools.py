import libvirt
import libvirt_qemu
import json
import time
import base64


def deunicodify_hook(pairs):
    new_pairs = []
    for key, value in pairs:
        if isinstance(value, unicode):
            value = value.encode('utf-8')
        if isinstance(key, unicode):
            key = key.encode('utf-8')
        new_pairs.append((key, value))
    return dict(new_pairs)


def guest_download_file(domain, path_guest, path_host, timeout=6, flags=0):
    result = None
    command = json.dumps({
        "execute": "guest-file-open",
        "arguments": {
            "path": path_guest,
            "mode": "r"
        }
    })

    result = libvirt_qemu.qemuAgentCommand(domain, command, timeout, flags)
    if result:
        handle = json.loads(result)["return"]
        command = json.dumps({
            "execute": "guest-file-read",
            "arguments": {
                "handle": handle
            }
        })
        eof = False
        output_file = open(path_host, 'wb')
        while not eof:
            response = libvirt_qemu.qemuAgentCommand(
                domain, command, timeout, flags)
            response_json = json.loads(
                response, object_pairs_hook=deunicodify_hook)
            output_file.write(
                base64.b64decode(response_json['return']['buf-b64']))
            eof = response_json['return']['eof']
        output_file.close()


def guest_exec(domain, cmd, args=[], timeout=6, flags=0, capture_output=True):
    command = json.dumps({
        "execute": "guest-exec",
        "arguments": {
            "path": cmd,
            "arg": args,
            "capture-output": capture_output
        }
    })
    result = None
    try:
        result = libvirt_qemu.qemuAgentCommand(domain, command, timeout, flags)
    except libvirt.libvirtError as e:
        print(e)
        pass
    if result:
        return json.loads(result)["return"]["pid"]
    else:
        return None


def guest_exec_get_response(domain, pid, timeout=6, flags=0):
    command = json.dumps({
        "execute": "guest-exec-status",
        "arguments": {
            "pid": pid
        }
    })
    response = None
    try:
        response = libvirt_qemu.qemuAgentCommand(domain,
                                                 command, timeout, flags)
    except libvirt.libvirtError as e:
        print(e)
        pass
    if response:
        response_json = json.loads(response)
        while (not response_json["return"]["exited"]):
            time.sleep(0.12)
            response_json = json.loads(libvirt_qemu.qemuAgentCommand(
                                       domain, command, timeout, flags))
        if "out-data" in response_json["return"].keys():
            result = str(
                response_json["return"]["out-data"]).decode('base64', 'strict')
            return result
        else:
            return ''
