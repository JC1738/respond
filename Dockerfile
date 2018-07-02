FROM scratch
ADD main /
ADD ca-certificates.crt /etc/ssl/certs/
ADD static /static
CMD ["/main"]
