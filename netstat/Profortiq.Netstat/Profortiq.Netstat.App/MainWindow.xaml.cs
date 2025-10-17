using System.Windows;
using LiveChartsCore;
using LiveChartsCore.SkiaSharpView;
using LiveChartsCore.SkiaSharpView.Painting;
using SkiaSharp;

namespace Profortiq.Netstat.App;

public partial class MainWindow : Window
{
    public ISeries[] Series { get; }

    public MainWindow()
    {
        InitializeComponent();

        Series = new ISeries[]
        {
            new ColumnSeries<double>
            {
                Values = new[] { 3d, 6d, 4d, 8d, 3d },
                Fill = new SolidColorPaint(new SKColor(33, 150, 243))
            }
        };

        MainChart.Series = Series;
    }
}
