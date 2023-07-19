#!/usr/bin/python
import csv
import config

ros_config = []


def get_ros_rule(
        comment, dst_addr, dst_port, in_int, proto, to_addr, to_ports):
    rule = ("/ip firewall nat add action=dst-nat chain=dstnat comment={}"
            " dst-address-list={} dst-port={} in-interface={} protocol={}"
            " to-addresses={} to-ports={}\n").format(
        comment,
        dst_addr, dst_port, in_int, proto, to_addr, to_ports
    )
    return rule


def get_ssh_port(offset):
    return config.SSH_PORT + offset*100


def get_tcp_ports(offset, multiplier):
    tcp_ports = []
    for tcp_port in config.TCP_PORTS:
        tcp_ports.append(
            (
                tcp_port + offset*multiplier,
                tcp_port + offset*100)
        )
    return tcp_ports


def get_udp_ports(offset):
    udp_ports = []
    for udp_port in config.UDP_PORTS:
        udp_ports.append(
            (
                udp_port,
                udp_port + offset*100)
        )
    return udp_ports


with open(config.OFFSETS_FILE) as csv_file:
    csv_reader = csv.reader(csv_file, delimiter=';')
    next(csv_reader)
    for row in csv_reader:
        if row:
            offset = int(row[2])
            hv = int(''.join(
                filter(str.isdigit, row[1].split(".")[1]))) + 10
            hv_ip = row[1]
            ros_config.append(get_ros_rule(
                "\"" + row[0].split(".")[1] + " SSH\"", row[5],
                get_ssh_port(offset),
                row[4], "tcp", hv_ip, config.SSH_PORT
            ))
            tcp_ports = get_tcp_ports(offset, int(row[6]))
            for tcp_port in tcp_ports:
                ros_config.append(
                    get_ros_rule(
                        row[0], row[5], tcp_port[1],
                        row[4], "tcp", hv_ip, tcp_port[0]))
            udp_ports = get_udp_ports(offset)
            for udp_port in udp_ports:
                ros_config.append(
                    get_ros_rule(
                        row[0], row[5], udp_port[1],
                        row[4], "udp", row[3], udp_port[0]))


with open("ros_config.rsc", "w") as ros_file:
    ros_file.writelines(ros_config)
