FROM scratch
ADD main /
ADD app_config /app_config
ADD ca-certificates.crt /etc/ssl/certs/
ADD static /static
CMD ["/main"]
