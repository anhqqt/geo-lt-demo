# Demo videos

| Video | Length | What it shows |
|---|---|---|
| [01. Successful load test](videos/01-successful-load-test.mp4) | 5:02 | Dispatch, live results, successful execution and cleanup. |
| [02. Input validation](videos/02-input-validation.mp4) | 3:46 | Five invalid numeric inputs rejected before the load job. |
| [03. HTTP failure and cleanup](videos/03-http-failure-cleanup.mp4) | 5:35 | A missing route returns 404; execution fails and cleanup succeeds. |
| [04. Cancel one run, preserve its peer](videos/04-cancel-run-preserve-peer.mp4) | 7:37 | Cancel A while B keeps running, then verify both cleanups. |

Open a video link above, or clone the repository and play the files in `docs/videos/`. On GitHub, use the file page's download button if inline playback is unavailable. Repository access is required. The recordings have no narration; use the notes below while watching.

## Recorded source and access

All four recordings use original workflow/workload revision `cc64599` and `bookinfo.js`. The [packaged runtime commit `a81a194`](https://github.com/anhqqt/geo-lt-demo/commit/a81a1941eef9ac5b23f45ed8249db712958d4e5a) contains the same workflows, policy, scripts and workloads. [Source provenance](validation.md#included-evidence-and-its-limits) explains how recorded SHAs relate to the submission history.

The form accepts a complete HTTP or HTTPS URL.

Lens shows the platform maintainer's Kubernetes view. The Grafana session in these recordings has editing controls; these videos do not demonstrate the Viewer permission boundary. Separate [Viewer checks](validation.md#upstream-dashboard-and-viewer-check) cover live and retained read access.

Grafana requires separately supplied Viewer access. The deployed Prometheus retention was read back as 10 days, so the historical links below can outlive their metrics. The MP4 files preserve the demonstrated results.

## Scenarios and results

### 01. Successful load test

Follow the GitHub dispatch, running k6 resources, live Grafana charts and final Summary. The run requests 20 total VUs for 60 seconds across two runners, targeting `https://bookinfo.demo.anhquach.dev/productpage`.

[Run `37054796485-1`](https://github.com/anhqqt/geo-lt-demo/actions/runs/37054796485) reports execution **succeeded** and cleanup **verified**. [Open its fixed-time Grafana view](https://grafana.demo.anhquach.dev/d/a3b2aaa8-bb66-4008-a1d8-16c49afedbf0?var-testid=37054796485-1&from=1790969587000&to=1790969725326). The early live view includes `All`; use the final Summary link for the specific run and interval.

### 02. Input validation

The five requests below fail validation and skip the load job. No AWS load resources are created by those rejected requests.

| Invalid input | Recorded run |
|---|---|
| VUs below the minimum | [37056876859](https://github.com/anhqqt/geo-lt-demo/actions/runs/37056876859) |
| VUs above the maximum | [37056960035](https://github.com/anhqqt/geo-lt-demo/actions/runs/37056960035) |
| Duration below the minimum | [37057021912](https://github.com/anhqqt/geo-lt-demo/actions/runs/37057021912) |
| Runner count above the maximum | [37057079403](https://github.com/anhqqt/geo-lt-demo/actions/runs/37057079403) |
| Fractional VUs | [37057132495](https://github.com/anhqqt/geo-lt-demo/actions/runs/37057132495) |

URL rejection is covered separately by [unsupported-protocol run 37064485458](https://github.com/anhqqt/geo-lt-demo/actions/runs/37064485458), which is not in this video. HTTP itself is accepted.

### 03. HTTP failure and cleanup

The run requests 20 total VUs for 60 seconds across two runners against `https://bookinfo.demo.anhquach.dev/load-test-nonexistent`. Grafana shows 404 responses.

[Run `37058145157-1`](https://github.com/anhqqt/geo-lt-demo/actions/runs/37058145157) reports execution **failed** and cleanup **verified**. The video shows the failed result, removed k6 resources and [retained Grafana results](https://grafana.demo.anhquach.dev/d/a3b2aaa8-bb66-4008-a1d8-16c49afedbf0?var-testid=37058145157-1&from=1790971484000&to=1790971615254). This is an intentional missing-route failure.

### 04. Cancel one run, preserve its peer

Runs A and B each request 20 VUs for 300 seconds across two runners against the public Productpage URL. The combined requested load is 40 VUs while both are active.

Watch both sets of running resources, cancellation of A and the fresh Lens view showing B's runners still Running after A's removal. The fresh resource view establishes that B continued; historical charts alone cannot show this.

| Run | Execution | Cleanup | Results |
|---|---|---|---|
| [A: `37060852199-1`](https://github.com/anhqqt/geo-lt-demo/actions/runs/37060852199) | cancelled | verified | The Summary has no measurement end or fixed-time Grafana link. |
| [B: `37060868805-1`](https://github.com/anhqqt/geo-lt-demo/actions/runs/37060868805) | succeeded | verified | [Fixed-time Grafana view](https://grafana.demo.anhquach.dev/d/a3b2aaa8-bb66-4008-a1d8-16c49afedbf0?var-testid=37060868805-1&from=1790972996000&to=1790973370774) |

The video demonstrates B continuing and both runs cleaning up. It does not measure exact cancellation latency or compare peer object UIDs; [earlier lifecycle checks](validation.md#access-rejection-and-recovery) provide the UID comparison and original-run recovery evidence.

## Reading the results

Native thresholds apply independently to each runner: `p(95)<1000ms` and HTTP-200 checks `rate>=0.99`. A green workflow does not certify whole-run performance or complete telemetry. The upstream dashboard averages VUs, rounds some panels and can show `No data`; missing data is not zero errors or a pass.

Cleanup removes each run's temporary k6 resources. Bookinfo, namespace controls, monitoring and the AWS foundation remain available and incur costs until the platform maintainer performs the separately authorized [foundation removal](setup.md#remove-the-foundation). The [validation record](validation.md#acceptance-coverage) defines the completed demo and the limits of its evidence.
