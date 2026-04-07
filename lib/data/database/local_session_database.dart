class LocalSessionDatabase {
  int appLaunches = 0;
  int startedRuns = 0;

  void markAppLaunch() {
    appLaunches += 1;
  }

  void markRunStarted() {
    startedRuns += 1;
  }
}
