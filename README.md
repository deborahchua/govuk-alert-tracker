# GOV.UK Alert Tracker

A script that scrapes Icinga for hard alerts and exports them to the [platform health dashboard](https://datastudio.google.com/reporting/1bXgS9j2mgMJtifuQrVHaZ5rYwxKCns0k/page/gKOG).

## Technical documentation

This is a simple Ruby app that runs monthly via a Jenkins job.

### Running the application

```
$ bundle exec rake run_monthly_report
```

## Licence

[MIT License](LICENCE)
