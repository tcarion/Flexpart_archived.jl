#!/usr/bin/env python3

"""

This script allows to make a mars retrieve request from an mars request file (`sys.argv[1]`).
"""
from ecmwfapi import ECMWFDataServer
import sys

def main():
    filepath = sys.argv[1]
    req_dict = {}

    with open(filepath) as f:
        for line in f:
            (key, val) = line.split()
            req_dict[key] = val
    server = ECMWFDataServer()
    server.retrieve(req_dict)


if __name__ == "__main__":
    main()