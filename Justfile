build:
    v -g -autofree -skip-unused -o ttyrtle.c .
    v -g -autofree -skip-unused .
publish:
    v -autofree -skip-unused -prod .
run: build
    ./ttyrtle
