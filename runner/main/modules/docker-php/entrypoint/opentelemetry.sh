if [ "$USE_OTEL" -eq 1 ]; then
    echo "==="
    echo "OpenTelemetry is enabled. Installing OpenTelemetry PHP extension and configuring it to export to the local OpenTelemetry Collector."
    echo "==="

    echo "Configuring OpenTelemetry PHP extension to export to the local OpenTelemetry Collector."

    cat << EOF >> /usr/local/etc/php/conf.d/20-opentelemetry.ini
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp
OTEL_METRICS_EXEMPLAR_FILTER=always_on
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_EXPORTER_OTLP_ENDPOINT=http://${COLLECTOR}:4317
OTEL_EXPORTER_OTLP_ENDPOINT=http://${COLLECTOR}:4318
#OTEL_PHP_INTERNAL_METRICS_ENABLED="true"
#OTEL_PHP_AUTOLOAD_ENABLED="true"
#OTEL_PHP_DISABLED_INSTRUMENTATIONS=moodle
EOF

    echo "Installing OpenTelemetry PHP extension."
    curl -sSLf \
            -o /usr/local/bin/install-php-extensions \
            https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions && \
        chmod +x /usr/local/bin/install-php-extensions && \
        install-php-extensions opentelemetry && \
        install-php-extensions protobuf

    echo "Installed OpenTelemetry PHP extension."
fi
