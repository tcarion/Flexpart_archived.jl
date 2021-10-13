#!/usr/bin/env python3
from polytope.api import Client
import sys



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