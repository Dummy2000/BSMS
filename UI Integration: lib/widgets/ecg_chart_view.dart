import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../services/ecg_processor.dart';

class EcgChartView extends StatefulWidget {
  final EcgDataProcessor processor;
  const EcgChartView({super.key, required this.processor});

  @override
  State<EcgChartView> createState() => _EcgChartViewState();
}

class _EcgChartViewState extends State<EcgChartView> {
  // Chart data list
  List<_ChartData> _chartData = [];
  ChartSeriesController? _seriesController;
  int _xCounter = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: widget.processor.signalStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _updateData(snapshot.data!);
        }

        return SfCartesianChart(
          title: ChartTitle(text: 'Real-time ECG Monitor (500Hz)'),
          primaryXAxis: NumericAxis(isVisible: false),
          series: <LineSeries<_ChartData, int>>[
            LineSeries<_ChartData, int>(
              onRendererCreated: (ChartSeriesController controller) {
                _seriesController = controller;
              },
              dataSource: _chartData,
              xValueMapper: (_ChartData data, _) => data.x,
              yValueMapper: (_ChartData data, _) => data.y,
              animationDuration: 0, // Critical for real-time performance
            )
          ],
        );
      },
    );
  }

  void _updateData(int newValue) {
    _chartData.add(_ChartData(_xCounter++, newValue));
    
    // Keep only the last 500 points on screen (1 second of data at 500Hz)
    if (_chartData.length > 500) {
      _chartData.removeAt(0);
      _seriesController?.updateDataSource(
        addedDataIndex: _chartData.length - 1,
        removedDataIndex: 0,
      );
    } else {
      _seriesController?.updateDataSource(
        addedDataIndex: _chartData.length - 1,
      );
    }
  }
}

class _ChartData {
  _ChartData(this.x, this.y);
  final int x;
  final int y;
}
