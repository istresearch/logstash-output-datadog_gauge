# Logstash Plugin

This is a plugin for [Logstash](https://github.com/elastic/logstash).

It is fully free and fully open source. The license is Apache 2.0, meaning you are pretty much free to use it however you want in whatever way.

## Installation

Edit the Logstash `Gemfile` to include the following:

    gem "logstash-output-datadog_gauge", :path => "/path/to/this/repo/dir"

Run the following

    # Logstash 2.3 and higher
    $ ./bin/logstash-plugin install --no-verify

    # Prior to Logstash 2.3
    $ ./bin/plugin install --no-verify

Ensure the plugin was installed correctly

    $ ./bin/logstash-plugin list | grep datadog_gauge

## Usage

Within a logstash config

    output {
        datadog_gauge {
            metric_name => "mymetric_name"
            queue_size => 100000
            timeframe => 60
            api_key => "DATADOG_API_KEY"
            host => "myhost.com"
        }
    }

