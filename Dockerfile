FROM trinodb/trino:latest
USER root
COPY entrypoint-single.sh setup-config.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint-single.sh /usr/local/bin/setup-config.sh
ENTRYPOINT ["/usr/local/bin/entrypoint-single.sh"]