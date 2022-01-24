#!/usr/bin/env python3

"""

This script allows to make a polytope retrieve request from an mars request file (`sys.argv[1]`). The result
of the request will be saved in the file `sys.argv[2]`.
"""
from polytope.api import Client
import sys

'''

    First argument: path to the YAML file with the m
'''
def main():
    filepath = sys.argv[1]
    output = sys.argv[2]
    output = output.replace('"', '')
    # c = Client(address = 'polytope.ecmwf.int', verbose=False, quiet=True)
    c = Client(address = 'polytope.ecmwf.int')
    # print("START RETRIEVING")
    files = c.retrieve('ecmwf-mars',filepath, inline_request = False, output_file=output)


if __name__ == "__main__":
    main()