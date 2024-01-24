#!/bin/sh

make -C writeup docker

perl populate.sh

cp writeup/main.pdf report.pdf

zip submission.zip conf/* dump.sql test.sql report.pdf

rm report.pdf
