# Event Detection

Event detection through deconvolution in Igor Pro. Accompanied by GUI for hyperparameter tuning, manual intervention and visualization. 

## purpose

1. Detect events from predefined kernels (or event-driven empirical averages) using deconvolution

2. Manually tune hyperparameters (e.g. detection threshold, kinetics of kernels, smoothing bin for maximum detection) and visualize results for intuition of performance and accuracy

3. Compile event amplitudes and intervals into distributions for subsequent analysis and visualization

## structure

This Igor procedure file `EventDetection.ipf` is built to supplement an existing analysis environment for electrophysiological data, `ECCLES Analysis`, originally developed by Dan Feldman, PhD. `EventDetection.ipf` adds the deconvolution code, as well as various visualization tools and user interfaces, to seamlessly incorporate event detection alongside preexisting analysis routines in `ECCLES Analysis`.

Raw electrophysiology data is formatted in an Igor Binary Test file, as indicated by `ECCLES Collect` data acquisition software (contact myself, Ken Burke, for this software package if interested). An example raw data .ibt file is provided.

```
.
├── README.md
├── sample_data.ibt
├── default_settings
│   └── AnalysisSettings.ipf
│   └── CollectFileDefaults.ipf
│   └── EventDetection.ipf
└── ECCLES Analysis V5.6.pxp
```

## beginning

To use the package, first make sure all .ipf files found in `default_settings` are found in your Igor Pro v6 User Procedures folder. Then open the Packed Experiment File (.pxp) and enter the path and file name sample .ibt file in the upper left hand corner (there will be an error due to your path likely being different from the default path, this can be corrected first in CollectFileDefaults.ipf before opening the ECCLES Analysis .pxp file alternatively).

Navigate to sweep 23 by entering that value in the “Sweep No.” section.

From the “—Analyses—-“ menu, open Event Detection, Mini’s > Mini EPSC Analysis

## usage

Given a problem where you have the following data trace, *t*
![](https://imgur.com/BpD6gq8.png)
and you would like to detect events of the following shape (or kernel, *k*)
![](https://imgur.com/ek8iU5R.png)

One approach would be to recover the original “signal” (i.e. event initiation time points) through deconvolution. This process involves taking the Fourier transform of the data trace (*T*) and the event kernel (*K*), and applying division in the frequency domain:

*F* = *T* / *K*

Then take the inverse Fourier transform of *F* to obtain the original signal of event locations, *f*.

This process is shown below, where the data trace *t* is shown in red above, and the deconvolved signal *f* given the aforementioned kernel *k* is shown in blue below (in green is a manually-determined event detection threshold):

![](https://imgur.com/waFfddX.png)

The process of then precisely identifying event locations (given the presence of noise in both the data trace and the deconvolved signal) is then non-trivial, as the resulting signal *f* is not a series of delta functions; instead we must define a noise threshold and detect maxima that cross this threshold in the deconvolved signal. 

One approach is to assume that the baseline noise in the deconvolved signal is approximately gassuian white noise. This turns out to be fairly accurate for a width of one standard deviation about the mean. Thus, we can fit the distribution of values of the deconvolved signal *f* (shown below in blue) to a gaussian (shown in red) as a way of detecting outliers not explained by this noise model:

![](https://imgur.com/Ex6uyoe.png)

We can then arbitrarily choose 3.5 standard deviations from the gaussian fit as a threshold for event detection (all values to right of green line):

![](https://imgur.com/cZdPMXX.png)

Then we can find the time points that are associated with these values, using a boxcar smoothing algorithm we can find the individual maxima and thereby define the timing of individual events (replotted below as black ticks):

![](https://imgur.com/jKA7K0g.png)
![](https://imgur.com/dvrgTrB.png)

In order to check the performance of this 3.5 SD detection threshold (as well as the other hyperparameters we will discuss later), we replot these event timings as arrowheads on the original data trace *t* to see how well the algorithm agrees with the experimenter intuition:

![](https://imgur.com/rCAGdTc.png) 

As this process has many hyperparameters, I developed a GUI and visualization system to observe the result of tuning these hyperparameters:

![](https://imgur.com/JL8KqUi.png)

Similarly, for the purposes of biological research, there are often unpredictable noise sources without clear patterns for exclusion, so I created another panel that allows for manual deletion of specific events, as well as concatenation of many event amplitudes and inter-event intervals across stimuli, and visualization of the average event shape, amplitudes and interval distributions:

![](https://imgur.com/tDxd3pR.png)
![](https://imgur.com/vXiwUkj.png)
![](https://imgur.com/ckZ9DeX.png)
![](https://imgur.com/U80xu2M.png)

Note that in the inter-event interval distribution, you see peaks that deviate from the *1/f* shape, particularly around 50, 100 and 200 milliseconds. This is due to the fact that in this particular experiment, there were many randomly-distributed spontaneous events, but there were also stimuli evoking these events at precisely these frequencies.


A normal working environment will look like this:

![](https://imgur.com/909LbAq.png)


## testing

Continuous integration testing is currently under development.

## contributors

Original design by Ken Burke. 
Used for event detection in multiple laboratory projects in the process of publication.