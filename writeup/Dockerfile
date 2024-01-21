FROM fedora:latest

RUN dnf in -y texlive texlive-perltex make
RUN dnf in -y texlive-appendix

WORKDIR /wdir

ENTRYPOINT ["make"]
