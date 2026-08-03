---
name: grafana-dashboards
description: Grafana dashboard and Prometheus query conventions for home-ops — stat panel config, metric aggregation across duplicate exporters, threshold settings, and SNMP unit conversions. Use when building or editing Grafana dashboards or writing Prometheus queries for this cluster.
---

# Grafana & Prometheus Guidelines

## Dashboard Best Practices

1. **Stat Panel Configuration**: Use `textMode: "value"` with proper mappings for status displays
2. **Metric Aggregation**: Use `max()` function when multiple pods query the same physical device to avoid duplicate lines/gauges
3. **Panel Organization**: Group related metrics by device/service with clear section headers including model numbers
4. **Threshold Settings**: Set appropriate warning levels (e.g., PDU at 90% load for 15A circuits)

## Common Prometheus Query Patterns

- **Multiple Pod Aggregation**: `max(metric_name)` - prevents duplicate data from multiple exporters
- **Device Status**: Map binary values (0/1) to meaningful text (Offline/Online)
- **Power Source Detection**: Use time-on-battery metric with 0 mapping to "Grid" for normal operation
- **Unit Conversions**: Apply necessary transformations in queries (e.g., `/10` for decivolts to volts)
