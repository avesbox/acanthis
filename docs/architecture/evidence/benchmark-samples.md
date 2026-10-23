# Raw benchmark observations

Recorded 2026-10-13 with the existing harnesses and unchanged library sources. No comparison establishes a refactor speedup. Lifecycle modes were run sequentially, with no other test/build benchmark processes during each timing run. This was an interactive desktop session: background load, CPU model and power policy were not controlled or fully recorded. Source files are pinned by [the manifest](source-fingerprint.md). Exact package lockfiles are fingerprinted there. Timing units and controls are retained below; allocation totals were not measured.

## continuous_jit.json

```json
{
  "sdk": "3.13.3 (stable) (Tue Sep 1 01:07:17 2026 -0700) on \"windows_x64\"",
  "mode": "jit",
  "executable": "C:\\tools\\dart-sdk\\bin\\dart.exe",
  "os": "windows",
  "processors": 12,
  "timestamp_utc": "2026-10-13T19:51:42.033478Z",
  "rounds": 5,
  "sample_ms": 100,
  "fresh_schemas_per_sample": 128,
  "order_seed": 42,
  "allocation": "separate --allocations process; not inferred from RSS or timing",
  "preflight": "passed",
  "rows": [
    {
      "case": "control.loop",
      "policy": "empty harness control",
      "process_first_construction_ns": 169400,
      "process_first_validation_ns": 552200,
      "construction": {
        "median_ns": 39.802698614870245,
        "min_ns": 35.795280043813335,
        "max_ns": 43.76708402077872,
        "samples_ns": [
          36.41452063972966,
          43.76708402077872,
          39.802698614870245,
          39.835638484336656,
          35.795280043813335
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 57.8125,
        "min_ns": 48.4375,
        "max_ns": 64.0625,
        "samples_ns": [
          59.375,
          64.0625,
          57.8125,
          48.4375,
          51.5625
        ]
      },
      "warm_validation": {
        "median_ns": 29.22637853383096,
        "min_ns": 27.920368046842324,
        "max_ns": 37.08140819792493,
        "samples_ns": [
          27.920368046842324,
          37.08140819792493,
          28.557830977790598,
          30.792524285296427,
          29.22637853383096
        ]
      }
    },
    {
      "case": "object.specialized.valid",
      "policy": "collect all",
      "process_first_construction_ns": 7133200,
      "process_first_validation_ns": 7498300,
      "construction": {
        "median_ns": 1256.3731155778894,
        "min_ns": 1199.631717850288,
        "max_ns": 1807.1214311528731,
        "samples_ns": [
          1807.1214311528731,
          1256.3731155778894,
          1249.108168873345,
          1199.631717850288,
          1275.0554634706107
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 5652.34375,
        "min_ns": 2313.28125,
        "max_ns": 6789.0625,
        "samples_ns": [
          4163.28125,
          5652.34375,
          6789.0625,
          2313.28125,
          6717.1875
        ]
      },
      "warm_validation": {
        "median_ns": 281.09343377557906,
        "min_ns": 267.928678598221,
        "max_ns": 438.0877907740833,
        "samples_ns": [
          438.0877907740833,
          299.8428832718659,
          267.928678598221,
          269.67693220430397,
          281.09343377557906
        ]
      }
    },
    {
      "case": "invalid90.nested",
      "policy": "collect all",
      "process_first_construction_ns": 2161500,
      "process_first_validation_ns": 6415100,
      "construction": {
        "median_ns": 1753.8846018940721,
        "min_ns": 1648.3945937036426,
        "max_ns": 3522.323125659979,
        "samples_ns": [
          1753.8846018940721,
          2020.9678722974338,
          3522.323125659979,
          1648.3945937036426,
          1720.8845293409051
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 4749.21875,
        "min_ns": 3638.28125,
        "max_ns": 8273.4375,
        "samples_ns": [
          4749.21875,
          8273.4375,
          5225,
          4707.03125,
          3638.28125
        ]
      },
      "warm_validation": {
        "median_ns": 1216.1777939924602,
        "min_ns": 1141.4849902979113,
        "max_ns": 1819.3596507185737,
        "samples_ns": [
          1198.9893298165687,
          1367.3229423024336,
          1819.3596507185737,
          1216.1777939924602,
          1141.4849902979113
        ]
      }
    },
    {
      "case": "invalid90.issues.json",
      "policy": "collect all",
      "process_first_construction_ns": 205200,
      "process_first_validation_ns": 5049100,
      "construction": {
        "median_ns": 1632.6824489795918,
        "min_ns": 1581.3235294117646,
        "max_ns": 1823.566739606127,
        "samples_ns": [
          1588.1943782753692,
          1632.6824489795918,
          1823.566739606127,
          1581.3235294117646,
          1673.7824267782428
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 12305.46875,
        "min_ns": 9384.375,
        "max_ns": 15444.53125,
        "samples_ns": [
          9384.375,
          15444.53125,
          12305.46875,
          9923.4375,
          13962.5
        ]
      },
      "warm_validation": {
        "median_ns": 4722.908404154863,
        "min_ns": 4413.852603706972,
        "max_ns": 5237.947643979058,
        "samples_ns": [
          4413.852603706972,
          5237.947643979058,
          4990.798403193613,
          4632.6817971283,
          4722.908404154863
        ]
      }
    },
    {
      "case": "issues100.repeated",
      "policy": "collect all",
      "process_first_construction_ns": 1384900,
      "process_first_validation_ns": 2366000,
      "construction": {
        "median_ns": 717.3228628800917,
        "min_ns": 674.7813765182186,
        "max_ns": 845.6511077287333,
        "samples_ns": [
          772.2069498069498,
          714.1159668666096,
          845.6511077287333,
          717.3228628800917,
          674.7813765182186
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 52490.625,
        "min_ns": 47103.90625,
        "max_ns": 59732.03125,
        "samples_ns": [
          59732.03125,
          49023.4375,
          58867.1875,
          52490.625,
          47103.90625
        ]
      },
      "warm_validation": {
        "median_ns": 47547.01421800948,
        "min_ns": 45179.63963963964,
        "max_ns": 54629.782608695656,
        "samples_ns": [
          52486.806282722515,
          47547.01421800948,
          54629.782608695656,
          46558.13953488372,
          45179.63963963964
        ]
      }
    },
    {
      "case": "issues1000.repeated",
      "policy": "collect all",
      "process_first_construction_ns": 16200,
      "process_first_validation_ns": 5527200,
      "construction": {
        "median_ns": 713.1712187121158,
        "min_ns": 686.3479752916953,
        "max_ns": 818.5921257264467,
        "samples_ns": [
          701.4119379953707,
          818.5921257264467,
          686.3479752916953,
          725.242584668939,
          713.1712187121158
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 476218.75,
        "min_ns": 458104.6875,
        "max_ns": 524092.96875,
        "samples_ns": [
          486303.125,
          524092.96875,
          476218.75,
          467812.5,
          458104.6875
        ]
      },
      "warm_validation": {
        "median_ns": 478494.7619047619,
        "min_ns": 435243.04347826086,
        "max_ns": 523873.5,
        "samples_ns": [
          478494.7619047619,
          523873.5,
          460962.7272727273,
          487191.90476190473,
          435243.04347826086
        ]
      }
    },
    {
      "case": "union16.invalid",
      "policy": "collect all",
      "process_first_construction_ns": 2955000,
      "process_first_validation_ns": 1455700,
      "construction": {
        "median_ns": 2170.3103298611113,
        "min_ns": 2088.200041762372,
        "max_ns": 2643.6214644462066,
        "samples_ns": [
          2170.3103298611113,
          2643.6214644462066,
          2088.200041762372,
          2236.2634168157424,
          2100.4829903401933
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 11451.5625,
        "min_ns": 7702.34375,
        "max_ns": 13924.21875,
        "samples_ns": [
          9696.875,
          7702.34375,
          11451.5625,
          13924.21875,
          13569.53125
        ]
      },
      "warm_validation": {
        "median_ns": 9981.79640718563,
        "min_ns": 9474.65909090909,
        "max_ns": 13093.429319371728,
        "samples_ns": [
          9926.051587301587,
          13093.429319371728,
          9474.65909090909,
          9981.79640718563,
          10081.179435483871
        ]
      }
    },
    {
      "case": "union16.last",
      "policy": "collect all",
      "process_first_construction_ns": 37600,
      "process_first_validation_ns": 316300,
      "construction": {
        "median_ns": 2163.5561323815705,
        "min_ns": 2129.18671492442,
        "max_ns": 2332.827151854444,
        "samples_ns": [
          2129.18671492442,
          2332.827151854444,
          2151.4931153184166,
          2220.477353463588,
          2163.5561323815705
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 6943.75,
        "min_ns": 5540.625,
        "max_ns": 15215.625,
        "samples_ns": [
          6269.53125,
          6988.28125,
          6943.75,
          5540.625,
          15215.625
        ]
      },
      "warm_validation": {
        "median_ns": 8084.721099434115,
        "min_ns": 7380.022123893806,
        "max_ns": 8267.314049586777,
        "samples_ns": [
          8232.469135802468,
          8267.314049586777,
          8084.721099434115,
          7380.022123893806,
          7599.186930091186
        ]
      }
    },
    {
      "case": "union128.invalid",
      "policy": "collect all",
      "process_first_construction_ns": 193700,
      "process_first_validation_ns": 1167900,
      "construction": {
        "median_ns": 16530.9900990099,
        "min_ns": 15687.57053291536,
        "max_ns": 22613.90519187359,
        "samples_ns": [
          16530.9900990099,
          22613.90519187359,
          15687.57053291536,
          16461.89144736842,
          16711.385642737896
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 84885.15625,
        "min_ns": 77000,
        "max_ns": 93235.9375,
        "samples_ns": [
          77000,
          93235.9375,
          84885.15625,
          85803.90625,
          79175.78125
        ]
      },
      "warm_validation": {
        "median_ns": 77806.74418604652,
        "min_ns": 75848.57142857143,
        "max_ns": 101027.67676767676,
        "samples_ns": [
          78329.453125,
          101027.67676767676,
          77806.74418604652,
          75848.57142857143,
          77256
        ]
      }
    },
    {
      "case": "union128.last",
      "policy": "collect all",
      "process_first_construction_ns": 283900,
      "process_first_validation_ns": 1257900,
      "construction": {
        "median_ns": 18316.53846153846,
        "min_ns": 15471.792890262752,
        "max_ns": 20930.7949790795,
        "samples_ns": [
          20930.7949790795,
          15471.792890262752,
          20104.317269076306,
          18316.53846153846,
          17516.14711033275
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 67034.375,
        "min_ns": 65601.5625,
        "max_ns": 80162.5,
        "samples_ns": [
          67034.375,
          66844.53125,
          65601.5625,
          72961.71875,
          80162.5
        ]
      },
      "warm_validation": {
        "median_ns": 65650.65359477124,
        "min_ns": 59490.769230769234,
        "max_ns": 80509.04761904762,
        "samples_ns": [
          60263.55421686747,
          59490.769230769234,
          80509.04761904762,
          68855.20547945205,
          65650.65359477124
        ]
      }
    },
    {
      "case": "transformed100.output",
      "policy": "collect all",
      "process_first_construction_ns": 683700,
      "process_first_validation_ns": 2972500,
      "construction": {
        "median_ns": 1228.5110565110565,
        "min_ns": 1120.6107126848947,
        "max_ns": 1308.9503991624133,
        "samples_ns": [
          1301.0251073240536,
          1308.9503991624133,
          1228.5110565110565,
          1133.613693040127,
          1120.6107126848947
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 12289.0625,
        "min_ns": 10157.8125,
        "max_ns": 20675.78125,
        "samples_ns": [
          10157.8125,
          20675.78125,
          13185.15625,
          12289.0625,
          11010.9375
        ]
      },
      "warm_validation": {
        "median_ns": 9490.170616113744,
        "min_ns": 8662.995670995671,
        "max_ns": 12145.376213592233,
        "samples_ns": [
          9498.53889943074,
          12145.376213592233,
          8662.995670995671,
          8876.84117125111,
          9490.170616113744
        ]
      }
    },
    {
      "case": "live50.independent",
      "policy": "session setup includes initial validation; update collects changed issues",
      "process_first_construction_ns": 20095300,
      "process_first_validation_ns": 3904200,
      "construction": {
        "median_ns": 150430.74626865672,
        "min_ns": 137184.1095890411,
        "max_ns": 189755.6603773585,
        "samples_ns": [
          150430.74626865672,
          189755.6603773585,
          149310.14925373133,
          156934.84375,
          137184.1095890411
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 51298.4375,
        "min_ns": 40571.09375,
        "max_ns": 71253.90625,
        "samples_ns": [
          67608.59375,
          71253.90625,
          40571.09375,
          50413.28125,
          51298.4375
        ]
      },
      "warm_validation": {
        "median_ns": 77747.98449612403,
        "min_ns": 71524.5,
        "max_ns": 102569.89795918367,
        "samples_ns": [
          86849.6551724138,
          102569.89795918367,
          77747.98449612403,
          74690.5223880597,
          71524.5
        ]
      }
    },
    {
      "case": "live50.full",
      "policy": "full parse after same field assignment; no delta calculation",
      "process_first_construction_ns": 481800,
      "process_first_validation_ns": 586300,
      "construction": {
        "median_ns": 38832.28682170543,
        "min_ns": 36314.67391304348,
        "max_ns": 46225.8064516129,
        "samples_ns": [
          36314.67391304348,
          38092.243346007606,
          38832.28682170543,
          46225.8064516129,
          39282.58823529412
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 35366.40625,
        "min_ns": 28292.96875,
        "max_ns": 90299.21875,
        "samples_ns": [
          34367.96875,
          35366.40625,
          28292.96875,
          90299.21875,
          47875
        ]
      },
      "warm_validation": {
        "median_ns": 23345.967365967364,
        "min_ns": 22941.487414187643,
        "max_ns": 27598.292011019283,
        "samples_ns": [
          23084.562211981567,
          22941.487414187643,
          24455.330073349633,
          27598.292011019283,
          23345.967365967364
        ]
      }
    },
    {
      "case": "async8.completed",
      "policy": "8 sequential controlled callbacks; 90% invalid; no network",
      "process_first_construction_ns": 595000,
      "process_first_validation_ns": 6454800,
      "construction": {
        "median_ns": 2064.249742002064,
        "min_ns": 1966.36846244593,
        "max_ns": 2239.153605015674,
        "samples_ns": [
          1976.7325558410753,
          2239.153605015674,
          1966.36846244593,
          2064.249742002064,
          2095.2629373559607
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 6171.09375,
        "min_ns": 4298.4375,
        "max_ns": 7447.65625,
        "samples_ns": [
          7085.9375,
          6171.09375,
          5646.875,
          7447.65625,
          4298.4375
        ]
      },
      "warm_validation": {
        "median_ns": 6222.980709396391,
        "min_ns": 5466.398907103825,
        "max_ns": 7347.891256429096,
        "samples_ns": [
          5466.398907103825,
          7347.891256429096,
          6594.034278180619,
          6222.980709396391,
          5975.250596658711
        ]
      }
    },
    {
      "case": "control.async8.completed",
      "policy": "callback scheduling control without validation",
      "process_first_construction_ns": 34400,
      "process_first_validation_ns": 107900,
      "construction": {
        "median_ns": 36.648733237802396,
        "min_ns": 35.45777531938431,
        "max_ns": 46.70401419797772,
        "samples_ns": [
          35.45777531938431,
          46.70401419797772,
          35.9441429136264,
          38.00804247766084,
          36.648733237802396
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 2458.59375,
        "min_ns": 1805.46875,
        "max_ns": 3214.84375,
        "samples_ns": [
          2259.375,
          2615.625,
          1805.46875,
          3214.84375,
          2458.59375
        ]
      },
      "warm_validation": {
        "median_ns": 2191.279579316389,
        "min_ns": 2059.164093061561,
        "max_ns": 2376.2342599192207,
        "samples_ns": [
          2059.164093061561,
          2376.2342599192207,
          2191.279579316389,
          2280.232558139535,
          2179.3876661582044
        ]
      }
    },
    {
      "case": "async8.microtask",
      "policy": "8 sequential controlled callbacks; 90% invalid; no network",
      "process_first_construction_ns": 39700,
      "process_first_validation_ns": 490800,
      "construction": {
        "median_ns": 2303.6250575771533,
        "min_ns": 2004.0164262820513,
        "max_ns": 2354.6621144337178,
        "samples_ns": [
          2121.0008481764207,
          2311.065157116451,
          2354.6621144337178,
          2004.0164262820513,
          2303.6250575771533
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 7867.1875,
        "min_ns": 5811.71875,
        "max_ns": 13472.65625,
        "samples_ns": [
          5811.71875,
          7867.1875,
          13472.65625,
          7350.78125,
          9923.4375
        ]
      },
      "warm_validation": {
        "median_ns": 6589.736495388669,
        "min_ns": 6256.116322701689,
        "max_ns": 7104.708806818182,
        "samples_ns": [
          6673.555703802535,
          7104.708806818182,
          6589.736495388669,
          6440.32195750161,
          6256.116322701689
        ]
      }
    },
    {
      "case": "control.async8.microtask",
      "policy": "callback scheduling control without validation",
      "process_first_construction_ns": 500,
      "process_first_validation_ns": 27800,
      "construction": {
        "median_ns": 35.76872037914692,
        "min_ns": 33.66587327504654,
        "max_ns": 38.28770086644894,
        "samples_ns": [
          38.28770086644894,
          33.66587327504654,
          35.03566623689669,
          36.652640992841775,
          35.76872037914692
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 2259.375,
        "min_ns": 1768.75,
        "max_ns": 2648.4375,
        "samples_ns": [
          2146.875,
          2648.4375,
          2259.375,
          1768.75,
          2278.90625
        ]
      },
      "warm_validation": {
        "median_ns": 2360.1840056617125,
        "min_ns": 2267.657596371882,
        "max_ns": 2479.677659310687,
        "samples_ns": [
          2267.657596371882,
          2360.1840056617125,
          2479.677659310687,
          2353.0110562220652,
          2400.775137988961
        ]
      }
    },
    {
      "case": "async8.event",
      "policy": "8 sequential controlled callbacks; 90% invalid; no network",
      "process_first_construction_ns": 27000,
      "process_first_validation_ns": 2575900,
      "construction": {
        "median_ns": 2057.297408473879,
        "min_ns": 1992.8053397091055,
        "max_ns": 2459.995081160846,
        "samples_ns": [
          1993.6244019138755,
          2287.5091491308326,
          2459.995081160846,
          1992.8053397091055,
          2057.297408473879
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 68061.71875,
        "min_ns": 42208.59375,
        "max_ns": 70416.40625,
        "samples_ns": [
          42208.59375,
          68061.71875,
          70416.40625,
          69398.4375,
          64330.46875
        ]
      },
      "warm_validation": {
        "median_ns": 64611.354838709674,
        "min_ns": 44742.35555555556,
        "max_ns": 71959.42857142857,
        "samples_ns": [
          44742.35555555556,
          71959.42857142857,
          67829.86486486487,
          61157.37804878049,
          64611.354838709674
        ]
      }
    },
    {
      "case": "control.async8.event",
      "policy": "callback scheduling control without validation",
      "process_first_construction_ns": 700,
      "process_first_validation_ns": 89500,
      "construction": {
        "median_ns": 36.172026752804236,
        "min_ns": 34.49555525659468,
        "max_ns": 41.47634611077469,
        "samples_ns": [
          34.49555525659468,
          41.47634611077469,
          36.115924546836794,
          37.09341187205804,
          36.172026752804236
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 57003.125,
        "min_ns": 41426.5625,
        "max_ns": 62035.15625,
        "samples_ns": [
          41426.5625,
          51862.5,
          62035.15625,
          57003.125,
          57296.875
        ]
      },
      "warm_validation": {
        "median_ns": 51648.969072164946,
        "min_ns": 39402.44094488189,
        "max_ns": 55813.666666666664,
        "samples_ns": [
          39402.44094488189,
          55813.666666666664,
          52767.42105263158,
          49125.63725490196,
          51648.969072164946
        ]
      }
    }
  ]
}
```

## continuous_aot.json

```json
{
  "sdk": "3.13.3 (stable) (Tue Sep 1 01:07:17 2026 -0700) on \"windows_x64\"",
  "mode": "aot",
  "executable": "E:\\Progetti\\serinus_nest\\acanthis\\.dart_tool\\architecture-review-continuous.exe",
  "os": "windows",
  "processors": 12,
  "timestamp_utc": "2026-10-13T19:53:29.450631Z",
  "rounds": 5,
  "sample_ms": 100,
  "fresh_schemas_per_sample": 128,
  "order_seed": 42,
  "allocation": "separate --allocations process; not inferred from RSS or timing",
  "preflight": "passed",
  "rows": [
    {
      "case": "control.loop",
      "policy": "empty harness control",
      "process_first_construction_ns": 200,
      "process_first_validation_ns": 200,
      "construction": {
        "median_ns": 26.908573289095905,
        "min_ns": 25.932364046969123,
        "max_ns": 39.71800330452466,
        "samples_ns": [
          26.88323803225451,
          25.932364046969123,
          27.17718966398156,
          26.908573289095905,
          39.71800330452466
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 6.25,
        "min_ns": 3.90625,
        "max_ns": 7.8125,
        "samples_ns": [
          3.90625,
          6.25,
          3.90625,
          6.25,
          7.8125
        ]
      },
      "warm_validation": {
        "median_ns": 21.389023164288922,
        "min_ns": 20.607529983926142,
        "max_ns": 32.25643192609414,
        "samples_ns": [
          21.247187406379673,
          20.607529983926142,
          21.65687777748902,
          21.389023164288922,
          32.25643192609414
        ]
      }
    },
    {
      "case": "object.specialized.valid",
      "policy": "collect all",
      "process_first_construction_ns": 20600,
      "process_first_validation_ns": 16400,
      "construction": {
        "median_ns": 1103.4502923976609,
        "min_ns": 1034.8116721854306,
        "max_ns": 1726.7040745856355,
        "samples_ns": [
          1075.3645161290322,
          1034.8116721854306,
          1156.5895686365213,
          1726.7040745856355,
          1103.4502923976609
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 3635.9375,
        "min_ns": 2635.15625,
        "max_ns": 4390.625,
        "samples_ns": [
          3166.40625,
          4390.625,
          2635.15625,
          3635.9375,
          3692.1875
        ]
      },
      "warm_validation": {
        "median_ns": 326.01240944677255,
        "min_ns": 294.6339235732595,
        "max_ns": 492.6152709359606,
        "samples_ns": [
          348.4043738682268,
          294.6339235732595,
          326.01240944677255,
          492.6152709359606,
          294.9942476179238
        ]
      }
    },
    {
      "case": "invalid90.nested",
      "policy": "collect all",
      "process_first_construction_ns": 8800,
      "process_first_validation_ns": 19900,
      "construction": {
        "median_ns": 1472.982766239505,
        "min_ns": 1340.5361930294905,
        "max_ns": 2256.5207581227437,
        "samples_ns": [
          1340.5361930294905,
          1472.982766239505,
          1550.16114037806,
          1405.7731234186112,
          2256.5207581227437
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 4127.34375,
        "min_ns": 2477.34375,
        "max_ns": 6642.1875,
        "samples_ns": [
          2477.34375,
          4371.09375,
          3914.0625,
          4127.34375,
          6642.1875
        ]
      },
      "warm_validation": {
        "median_ns": 1355.635082011658,
        "min_ns": 1313.5977932483909,
        "max_ns": 2257.752200406229,
        "samples_ns": [
          1317.7054794520548,
          1355.635082011658,
          1374.8226560351939,
          1313.5977932483909,
          2257.752200406229
        ]
      }
    },
    {
      "case": "invalid90.issues.json",
      "policy": "collect all",
      "process_first_construction_ns": 3600,
      "process_first_validation_ns": 36000,
      "construction": {
        "median_ns": 1414.3388488191204,
        "min_ns": 1357.9660556687033,
        "max_ns": 2217.058301928619,
        "samples_ns": [
          1357.9660556687033,
          1383.2214857774095,
          1414.3388488191204,
          1524.7507241957614,
          2217.058301928619
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 6363.28125,
        "min_ns": 5431.25,
        "max_ns": 12054.6875,
        "samples_ns": [
          6007.03125,
          6363.28125,
          5431.25,
          11996.09375,
          12054.6875
        ]
      },
      "warm_validation": {
        "median_ns": 5924.982227488152,
        "min_ns": 5253.855042016807,
        "max_ns": 9007.587758775877,
        "samples_ns": [
          5253.855042016807,
          5924.982227488152,
          5563.159065628476,
          7038.306394940267,
          9007.587758775877
        ]
      }
    },
    {
      "case": "issues100.repeated",
      "policy": "collect all",
      "process_first_construction_ns": 4100,
      "process_first_validation_ns": 63200,
      "construction": {
        "median_ns": 689.608992483277,
        "min_ns": 631.6567710965134,
        "max_ns": 744.0818452380952,
        "samples_ns": [
          631.6567710965134,
          695.2144595064303,
          654.1008370389746,
          744.0818452380952,
          689.608992483277
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 67910.15625,
        "min_ns": 55407.8125,
        "max_ns": 72113.28125,
        "samples_ns": [
          63121.875,
          70110.15625,
          55407.8125,
          72113.28125,
          67910.15625
        ]
      },
      "warm_validation": {
        "median_ns": 63695.28662420382,
        "min_ns": 60281.49700598802,
        "max_ns": 73362.55474452555,
        "samples_ns": [
          63695.28662420382,
          60281.49700598802,
          69804.65277777778,
          73362.55474452555,
          60777.09090909091
        ]
      }
    },
    {
      "case": "issues1000.repeated",
      "policy": "collect all",
      "process_first_construction_ns": 1000,
      "process_first_validation_ns": 723800,
      "construction": {
        "median_ns": 748.3618947841054,
        "min_ns": 620.1376658811856,
        "max_ns": 927.5679436044894,
        "samples_ns": [
          625.793491864831,
          748.3618947841054,
          620.1376658811856,
          927.5679436044894,
          883.1367008124338
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 688795.3125,
        "min_ns": 603427.34375,
        "max_ns": 943301.5625,
        "samples_ns": [
          603427.34375,
          688795.3125,
          647239.84375,
          943301.5625,
          758882.8125
        ]
      },
      "warm_validation": {
        "median_ns": 734827.1428571428,
        "min_ns": 592865.2941176471,
        "max_ns": 944159.0909090909,
        "samples_ns": [
          592865.2941176471,
          734827.1428571428,
          607284.1176470588,
          944159.0909090909,
          841110
        ]
      }
    },
    {
      "case": "union16.invalid",
      "policy": "collect all",
      "process_first_construction_ns": 40500,
      "process_first_validation_ns": 46100,
      "construction": {
        "median_ns": 2678.36368505624,
        "min_ns": 2520.3326612903224,
        "max_ns": 4088.4464431725264,
        "samples_ns": [
          2520.3326612903224,
          2678.36368505624,
          2598.8591476091474,
          4088.4464431725264,
          3845.98001537279
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 12896.09375,
        "min_ns": 8698.4375,
        "max_ns": 18175.78125,
        "samples_ns": [
          12896.09375,
          11109.375,
          8698.4375,
          17404.6875,
          18175.78125
        ]
      },
      "warm_validation": {
        "median_ns": 10451.08672936259,
        "min_ns": 9621.663461538461,
        "max_ns": 15974.483306836248,
        "samples_ns": [
          9621.663461538461,
          10451.08672936259,
          10225.654396728016,
          15974.483306836248,
          14869.747399702823
        ]
      }
    },
    {
      "case": "union16.last",
      "policy": "collect all",
      "process_first_construction_ns": 9300,
      "process_first_validation_ns": 24000,
      "construction": {
        "median_ns": 2692.8532974427994,
        "min_ns": 2574.3026248069996,
        "max_ns": 2798.416340235031,
        "samples_ns": [
          2574.3026248069996,
          2692.8532974427994,
          2798.416340235031,
          2599.5217052248504,
          2789.7350069735007
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 5767.96875,
        "min_ns": 4903.125,
        "max_ns": 8515.625,
        "samples_ns": [
          5096.875,
          4903.125,
          7496.09375,
          8515.625,
          5767.96875
        ]
      },
      "warm_validation": {
        "median_ns": 7147.7,
        "min_ns": 6882.711631108053,
        "max_ns": 7590.2200303490135,
        "samples_ns": [
          7147.7,
          7590.2200303490135,
          7076.407355021216,
          6882.711631108053,
          7150.47891350965
        ]
      }
    },
    {
      "case": "union128.invalid",
      "policy": "collect all",
      "process_first_construction_ns": 67300,
      "process_first_validation_ns": 187800,
      "construction": {
        "median_ns": 20001.7,
        "min_ns": 19608.176470588234,
        "max_ns": 25984.363636363636,
        "samples_ns": [
          20330.243407707912,
          19608.176470588234,
          19980.518962075847,
          25984.363636363636,
          20001.7
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 72913.28125,
        "min_ns": 67655.46875,
        "max_ns": 95147.65625,
        "samples_ns": [
          74322.65625,
          72501.5625,
          72913.28125,
          95147.65625,
          67655.46875
        ]
      },
      "warm_validation": {
        "median_ns": 81184.75806451614,
        "min_ns": 76946.23076923077,
        "max_ns": 96572.78846153847,
        "samples_ns": [
          76946.23076923077,
          81184.75806451614,
          79852.46031746031,
          96154.61538461539,
          96572.78846153847
        ]
      }
    },
    {
      "case": "union128.last",
      "policy": "collect all",
      "process_first_construction_ns": 48800,
      "process_first_validation_ns": 102900,
      "construction": {
        "median_ns": 19394.042553191488,
        "min_ns": 18991.499051233397,
        "max_ns": 27427.013698630137,
        "samples_ns": [
          18991.499051233397,
          19394.042553191488,
          19289.47976878613,
          19459.78640776699,
          27427.013698630137
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 64670.3125,
        "min_ns": 47842.1875,
        "max_ns": 72848.4375,
        "samples_ns": [
          47842.1875,
          64670.3125,
          71539.0625,
          61796.875,
          72848.4375
        ]
      },
      "warm_validation": {
        "median_ns": 58919.23976608187,
        "min_ns": 55748.11111111111,
        "max_ns": 85331.01694915254,
        "samples_ns": [
          58919.23976608187,
          55748.11111111111,
          62379.68944099379,
          57068.579545454544,
          85331.01694915254
        ]
      }
    },
    {
      "case": "transformed100.output",
      "policy": "collect all",
      "process_first_construction_ns": 103500,
      "process_first_validation_ns": 45500,
      "construction": {
        "median_ns": 1143.841930687407,
        "min_ns": 1038.3470044647493,
        "max_ns": 1460.2321506789312,
        "samples_ns": [
          1075.400580707603,
          1143.841930687407,
          1038.3470044647493,
          1353.3712275003384,
          1460.2321506789312
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 14048.4375,
        "min_ns": 9049.21875,
        "max_ns": 16719.53125,
        "samples_ns": [
          14953.125,
          16719.53125,
          14048.4375,
          9049.21875,
          12932.8125
        ]
      },
      "warm_validation": {
        "median_ns": 10509.0756302521,
        "min_ns": 10091.009081735621,
        "max_ns": 13933.871866295265,
        "samples_ns": [
          10509.0756302521,
          10091.009081735621,
          10183.81485249237,
          13933.871866295265,
          13130.760157273919
        ]
      }
    },
    {
      "case": "live50.independent",
      "policy": "session setup includes initial validation; update collects changed issues",
      "process_first_construction_ns": 459300,
      "process_first_validation_ns": 82300,
      "construction": {
        "median_ns": 122413.01204819277,
        "min_ns": 115961.83908045977,
        "max_ns": 167957.16666666666,
        "samples_ns": [
          115961.83908045977,
          122413.01204819277,
          120829.75903614458,
          126351.625,
          167957.16666666666
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 57090.625,
        "min_ns": 52009.375,
        "max_ns": 118735.15625,
        "samples_ns": [
          57090.625,
          118735.15625,
          54111.71875,
          52009.375,
          105989.0625
        ]
      },
      "warm_validation": {
        "median_ns": 81645.77235772357,
        "min_ns": 77811.5503875969,
        "max_ns": 86369.91379310345,
        "samples_ns": [
          78197.03125,
          77811.5503875969,
          86369.91379310345,
          83620.66115702479,
          81645.77235772357
        ]
      }
    },
    {
      "case": "live50.full",
      "policy": "full parse after same field assignment; no delta calculation",
      "process_first_construction_ns": 66100,
      "process_first_validation_ns": 37300,
      "construction": {
        "median_ns": 33182.649006622516,
        "min_ns": 32701.56862745098,
        "max_ns": 47123.427230046946,
        "samples_ns": [
          33182.649006622516,
          32701.56862745098,
          33051.683168316835,
          35478.62190812721,
          47123.427230046946
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 34821.09375,
        "min_ns": 32255.46875,
        "max_ns": 60916.40625,
        "samples_ns": [
          34657.03125,
          32255.46875,
          34821.09375,
          44235.9375,
          60916.40625
        ]
      },
      "warm_validation": {
        "median_ns": 31476.32075471698,
        "min_ns": 31050.835913312694,
        "max_ns": 47457.48815165877,
        "samples_ns": [
          31376.614420062695,
          31476.32075471698,
          31050.835913312694,
          31830.4126984127,
          47457.48815165877
        ]
      }
    },
    {
      "case": "async8.completed",
      "policy": "8 sequential controlled callbacks; 90% invalid; no network",
      "process_first_construction_ns": 3500,
      "process_first_validation_ns": 44000,
      "construction": {
        "median_ns": 2334.3477246207704,
        "min_ns": 2177.0091423595995,
        "max_ns": 3805.577946768061,
        "samples_ns": [
          2334.3477246207704,
          2177.0091423595995,
          2355.85394581861,
          3805.577946768061,
          2306.280459770115
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 7953.125,
        "min_ns": 3760.9375,
        "max_ns": 8782.8125,
        "samples_ns": [
          8321.875,
          3760.9375,
          7953.125,
          8782.8125,
          4642.96875
        ]
      },
      "warm_validation": {
        "median_ns": 5579.983268265477,
        "min_ns": 5373.7399247716285,
        "max_ns": 7956.778042959427,
        "samples_ns": [
          5407.2,
          5373.7399247716285,
          5579.983268265477,
          7956.778042959427,
          5850.250728862974
        ]
      }
    },
    {
      "case": "control.async8.completed",
      "policy": "callback scheduling control without validation",
      "process_first_construction_ns": 200,
      "process_first_validation_ns": 4700,
      "construction": {
        "median_ns": 27.08224327413161,
        "min_ns": 26.31168762826922,
        "max_ns": 45.80478934398446,
        "samples_ns": [
          27.029537849424003,
          26.31168762826922,
          27.08224327413161,
          27.492899972782084,
          45.80478934398446
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 2339.84375,
        "min_ns": 1900,
        "max_ns": 2500,
        "samples_ns": [
          1900,
          2339.84375,
          2160.15625,
          2500,
          2415.625
        ]
      },
      "warm_validation": {
        "median_ns": 2139.760376551134,
        "min_ns": 2033.3197804431795,
        "max_ns": 2911.484716157205,
        "samples_ns": [
          2158.89896373057,
          2033.3197804431795,
          2123.2250530785564,
          2139.760376551134,
          2911.484716157205
        ]
      }
    },
    {
      "case": "async8.microtask",
      "policy": "8 sequential controlled callbacks; 90% invalid; no network",
      "process_first_construction_ns": 2600,
      "process_first_validation_ns": 13600,
      "construction": {
        "median_ns": 2234.530831099196,
        "min_ns": 2082.7446897126197,
        "max_ns": 3442.5301204819275,
        "samples_ns": [
          2082.7446897126197,
          2130.5155517682147,
          2234.530831099196,
          2306.0179847821073,
          3442.5301204819275
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 6254.6875,
        "min_ns": 5357.8125,
        "max_ns": 10960.15625,
        "samples_ns": [
          7543.75,
          5357.8125,
          5833.59375,
          6254.6875,
          10960.15625
        ]
      },
      "warm_validation": {
        "median_ns": 5731.386819484241,
        "min_ns": 5069.452610238216,
        "max_ns": 7942.006344171293,
        "samples_ns": [
          5069.452610238216,
          6027.823990355636,
          5731.386819484241,
          5650.836158192091,
          7942.006344171293
        ]
      }
    },
    {
      "case": "control.async8.microtask",
      "policy": "callback scheduling control without validation",
      "process_first_construction_ns": 0,
      "process_first_validation_ns": 2100,
      "construction": {
        "median_ns": 27.913785740006197,
        "min_ns": 26.698232845735095,
        "max_ns": 38.335805990347055,
        "samples_ns": [
          26.698232845735095,
          27.108967095168644,
          27.913785740006197,
          30.837959022561027,
          38.335805990347055
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 2397.65625,
        "min_ns": 1396.09375,
        "max_ns": 3393.75,
        "samples_ns": [
          1505.46875,
          1396.09375,
          2397.65625,
          3393.75,
          2617.96875
        ]
      },
      "warm_validation": {
        "median_ns": 2231.751841106896,
        "min_ns": 2164.9945875730677,
        "max_ns": 3061.542699724518,
        "samples_ns": [
          2164.9945875730677,
          2231.751841106896,
          2180.774095071958,
          2416.0980913264075,
          3061.542699724518
        ]
      }
    },
    {
      "case": "async8.event",
      "policy": "8 sequential controlled callbacks; 90% invalid; no network",
      "process_first_construction_ns": 2000,
      "process_first_validation_ns": 118900,
      "construction": {
        "median_ns": 2325.0709137409904,
        "min_ns": 2117.0046570702793,
        "max_ns": 3341.1760775141997,
        "samples_ns": [
          2117.0046570702793,
          2245.847743094543,
          2325.0709137409904,
          3341.1760775141997,
          3262.9823989569754
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 65469.53125,
        "min_ns": 59350,
        "max_ns": 77614.84375,
        "samples_ns": [
          65469.53125,
          59350,
          62903.125,
          72868.75,
          77614.84375
        ]
      },
      "warm_validation": {
        "median_ns": 62046.666666666664,
        "min_ns": 59298.757396449706,
        "max_ns": 74165.33333333333,
        "samples_ns": [
          59298.757396449706,
          62046.666666666664,
          61920.555555555555,
          73188.68613138686,
          74165.33333333333
        ]
      }
    },
    {
      "case": "control.async8.event",
      "policy": "callback scheduling control without validation",
      "process_first_construction_ns": 200,
      "process_first_validation_ns": 27500,
      "construction": {
        "median_ns": 26.754971494003172,
        "min_ns": 26.459882888675445,
        "max_ns": 37.30219597808125,
        "samples_ns": [
          26.5855454678382,
          26.459882888675445,
          28.645198067023966,
          26.754971494003172,
          37.30219597808125
        ]
      },
      "fresh_schema_first_validation": {
        "median_ns": 53621.875,
        "min_ns": 48050.78125,
        "max_ns": 56789.0625,
        "samples_ns": [
          50560.15625,
          53621.875,
          48050.78125,
          53833.59375,
          56789.0625
        ]
      },
      "warm_validation": {
        "median_ns": 49306.25615763547,
        "min_ns": 48391.11111111111,
        "max_ns": 55544.97237569061,
        "samples_ns": [
          48391.11111111111,
          49306.25615763547,
          52605.34031413613,
          48652.71844660194,
          55544.97237569061
        ]
      }
    }
  ]
}
```

## architecture-review-errors-jit.json

```json
{
  "runtime": "3.13.3 (stable) (Tue Sep 1 01:07:17 2026 -0700) on \"windows_x64\"",
  "os": "windows",
  "processors": 12,
  "samples": {
    "collect": {
      "microsecondsPerOperation": [
        2.5006,
        1.4418,
        0.7868,
        0.7277,
        0.79245,
        0.75035,
        0.7616
      ],
      "median": 0.7868
    },
    "fallback": {
      "microsecondsPerOperation": [
        3.38075,
        3.7905,
        3.52905,
        3.27415,
        3.121,
        3.1327,
        3.03905
      ],
      "median": 3.27415
    },
    "english": {
      "microsecondsPerOperation": [
        3.54945,
        3.39185,
        3.4732,
        3.80405,
        3.99845,
        3.9535,
        3.8962
      ],
      "median": 3.80405
    },
    "italian": {
      "microsecondsPerOperation": [
        3.54685,
        3.32705,
        3.55385,
        3.3633,
        3.4711,
        3.33785,
        3.5139
      ],
      "median": 3.4711
    },
    "transport": {
      "microsecondsPerOperation": [
        3.00625,
        2.8373,
        3.1852,
        3.1144,
        3.1242,
        3.15205,
        3.23535
      ],
      "median": 3.1242
    },
    "validateFallback": {
      "microsecondsPerOperation": [
        8.7528,
        7.6898,
        7.1465,
        6.89915,
        7.1523,
        6.7261,
        7.6466
      ],
      "median": 7.1523
    },
    "validateItalian": {
      "microsecondsPerOperation": [
        7.0389,
        7.15435,
        7.6499,
        7.1693,
        7.3849,
        7.2509,
        7.04375
      ],
      "median": 7.1693
    }
  },
  "sink": 137315000
}
```

## architecture-review-live-jit.json

```json
{
  "dart": "3.13.3 (stable) (Tue Sep 1 01:07:17 2026 -0700) on \"windows_x64\"",
  "os": "windows",
  "processors": 12,
  "iterations": 10000,
  "samples": 7,
  "field_count": 24,
  "live_fields_per_edit": 1,
  "live_rules_per_edit": 1,
  "results": {
    "construct": {
      "median_us": 17.3955,
      "samples_us": [
        18.5149,
        16.6016,
        16.1299,
        17.3955,
        35.8971,
        21.8298,
        16.8409
      ]
    },
    "sync_full": {
      "median_us": 17.3171,
      "samples_us": [
        17.307,
        17.3171,
        24.9647,
        27.5775,
        20.248,
        16.8754,
        17.3008
      ]
    },
    "sync_live": {
      "median_us": 24.5053,
      "samples_us": [
        28.539,
        26.9294,
        24.5053,
        23.2395,
        23.2038,
        22.9949,
        25.683
      ]
    },
    "async_full": {
      "median_us": 40.7278,
      "samples_us": [
        45.622,
        41.1995,
        39.1514,
        56.9397,
        39.4737,
        39.3094,
        40.7278
      ]
    },
    "async_live": {
      "median_us": 32.6029,
      "samples_us": [
        32.8138,
        31.0756,
        31.8178,
        36.8032,
        32.4069,
        37.7807,
        32.6029
      ]
    }
  },
  "sink": 5328000
}
```
