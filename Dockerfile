FROM trinodb/trino:latest
COPY entrypoint-single.sh /etc/trino/entrypoint.sh
RUN chmod +x /etc/trino/entrypoint.sh
ENTRYPOINT ["/etc/trino/entrypoint.sh"]