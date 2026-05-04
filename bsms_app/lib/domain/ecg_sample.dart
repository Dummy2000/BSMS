class EcgSample {
  final int value;        // raw ADC value 0..4095
  final int timestampMs;  // absolute timestamp in ms

  EcgSample({
    required this.value,
    required this.timestampMs,
  });
}
