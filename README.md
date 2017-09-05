# Data Stash - Event API Client

Data Stash can ingest data from different data sources, transform them, and then send JSON output via HTTP to the Openbridge Events API. You can also store the outputs into other formats such as CSV.

![Data Stash](https://github.com/openbridge/ob_datastash/blob/master/datastash.png "How It Works")

A the heart of Data Stash is [Logstash](https://www.elastic.co/products/logstash). For a deeper dive into the capabilities of Logstash check our their [documentation](https://www.elastic.co/guide/en/logstash/current/index.html).

Data Stash is based on a premise of inputs, filters and outputs;

- **Inputs**: Your data sources. Primarily this will be a CSV file, but it an be many others.
- **Filters**: This is pre-processing your data prior to delivery to an output location
- **Outputs**: Ther are a few output options but the principle is the Openbridge Webhook API


## Quick Start Sample Config Files
For reference, sample configs can be found in the [`/config/pipeline`](config/pipeline) folder of this repo.

- **CSV to API**: CSV files with header rows use [`sample-csv-api-header.conf`](config/pipeline/sample-csv-api-header.conf)
- **CSV to API**: CSV without header rows use [`sample-csv-api-noheader.conf`](config/pipeline/sample-csv-api-noheader.conf)
- **CSV to CSV**: To process one CSV to generate a clean processed CSV use[`sample-csv-csv-noheader.conf`](config/pipeline/sample-csv-csv-noheader.conf)
- **Multiple CSV Inputs to Multiple CSV Outputs**: To process multiple CSV files to generate multiple clean CSV files use [`sample-multi-csv-csv-noheader.conf`](config/pipeline/sample-multi-csv-csv-noheader.conf)

# Install

Data Stash is neatly packaged into a Docker image so you can run this on your local laptop or deploy it to a server. The first step is to build or pull the image:

```docker
docker build -t openbridge/ob_datastash .
```

or simply pull it from Docker Hub:

```docker
docker pull openbridge/ob_datastash:latest
```

Once you have your image you are ready yo get started!

# Getting Started: How To Stream CSV Files

Data Stash can take a CSV file and break each row into a streamed JSON "event". These JSON events are delivered to an Openbridge API for import into your target warehouse.

There are a couple of CSV file use cases:

- **Static Files**: You have exports from a system that you want to load to your data warehouse. Data Stash will process the exported source file and stream the content of the file until it reaches the end.
- **Dynamic Files**: You have a file that continually has new rows added. Data Stash will process changing files and stream new events as they are appended to a file.

For our example walk-thru we use a static CSV file called `sales.csv`.

## `sales.csv` Needs A Data Stash Configuration File

To run Data Stash for `sales.csv` you need to define a config file. Each config file is comprised of three parts; input, filter and output. A config file describes how Data Stash should process your `sales.csv` file.

### Step 1: Define Your Input

Lets dig into your example `sales.csv`. The principle part of the input is setting the `path =>` to your file(s). You will need to specify the path to the file you want to process like this `path => "/the/path/to/your/sales.csv"`. We are going to assume this is located in a folder on your laptop here: `/Users/bob/csv/mysalesdata`.

However, Data Stash has its own location where it references your data. It will use its own default directory called `/data` to reference your files. What does this mean? In the Data Stash config you will use the `/data` in the file path as a default. When you run Data Stash you will tell it to map your laptop directory `/Users/bob/csv/mysalesdata` to the `/data`. This means anything in your laptop directory will appear exactly the same way inside `/data`.

See the "How To Run" section for more details on this mapping.

```bash
 input {
   file {
      path => "/data/sales.csv"
      start_position => "beginning"
      sincedb_path => "/dev/null"
   }
 }
```

### Step 2: Define Your Filter

This is where you define a CSV filter. A basic filter is focused on setting the schema and removal of system generated columns.

- The `separator => ","` defines the delimiter. Do not change
- The removal of system generated columns is done via `remove_field => [ "message", "host", "@timestamp", "@version", "path" ]`. Do not change unless you want to remove other columns from your CSV file. For example, lets say you had a column called `userid`. You can add it like this `remove_field => [ "message", "host", "@timestamp", "@version", "path", "userid" ]`. Now `userid` will be supressed and not sent to Openbridge.
- If your CSV file has a header row, then you can set `autodetect_column_names => "true"` and `autogenerate_column_names => "true"` to leverage those values when processing the file.

```bash
 filter {
   csv {
      separator => ","
      remove_field => [ "message", "host", "@timestamp", "@version", "path" ]
      autodetect_column_names => "true"
      autogenerate_column_names => "true"
   }
 }
```

If your CSV does **not** have a header in the file you need to provide context about the target source file. You need to supply the header to the application `columns => [Sku,Name,SearchKeywords,Main,Price,ID,Brands]`. This header should align to the laytout of the CSV file.

```bash
  filter {
    csv {
       separator => ","
       remove_field => [ "message", "host", "@timestamp", "@version", "path" ]
       columns => ["Sku","Name","SearchKeywords","Main","Price","ID","Brands"]
    }
  }
```

#### Advanced Filtering

Here is a more advance filter. This performs pre-prcoessing cleanup on the CSV file. For example, it will strip whitespace from columns, removed bad characters, convert a column to a different data type and so forth.

```bash

filter {

# The CSV filter takes an event field containing CSV data,
# parses it, and stores it as individual fields (can optionally specify the names).
# This filter can also parse data with any separator, not just commas.

  csv {
  # Set the comma delimiter
    separator => ","

  # We want to exclude these system columns
    remove_field => [
       "message",
       "host",
       "@timestamp",
       "@version",
       "path"
    ]

  # Define the layout of the input file
    columns => [
    "Sku","Name","SearchKeywords","Main","Price","ID","Brands"
    ]
  }

  # The mutate filter allows you to perform general
  # mutations on fields. You can rename, remove, replace
  # and modify fields in your events

  # We need to set the target column to "string" to allow for find and replace
  mutate {
    convert => [ "Sku", "string" ]
  }

  # Strip backslashes, question marks, equals, hashes, and minuses from the target column
  mutate {
     gsub => [ "Sku", "[\\?#=]", "" ]
  }

  # Strip extraneous white space from records
  mutate {
     strip => [ "Sku","Name","SearchKeywords","Main","Price","ID","Brands"
     ]
  }

  # Set everything to lowercase
  mutate {
     lowercase => [ "Sku","Name","SearchKeywords","Main","Price","ID","Brands"
     ]
  }
}
```

### Step 3: Define Your Output Destination

The output defines the delivery location for all the records in your CSV(s). Openbridge generates a private API endpoint which you use in the `url => ""`. The delivery API would look like this `url => "https://myapi.foo-api.us-east-1.amazonaws.com/dev/events/teststash?token=774f77b389154fd2ae7cb5131201777&sign=ujguuuljNjBkFGHyNTNmZTIxYjEzMWE5MjgyNzM1ODQ="`

You would take the Openberidge provided endpoint and put it into the config:

```bash
   output {
     http {
        url => "https://myapi.foo-api.us-east-1.amazonaws.com/dev/events/teststash?token=774f77b389154fd2ae7cb5131201777&sign=ujguuuljNjBkFGHyNTNmZTIxYjEzMWE5MjgyNzM1ODQ="
        http_method => "post"
        format => "json"
        pool_max => "10"
        pool_max_per_route => "5"
     }
   }
```

**Note**: Do not change `http_method => "post"`, `format => "json"`, `pool_max => "10"`, `pool_max_per_route => "5"` from the defaults listed in the config.

You can also store the data to a CSV file (vs sending it to an API). This might be useful to test or validate your data prior to using the API. It also might be useful if you want to create a CSV for upload to Openbridge via SFTP or SCP.

```bash
output {

  # Saving output to CSV so we define the layout of the file
    csv {
      fields => [ "Sku","Name","SearchKeywords","Main","Price","ID","Brands" ]

   # Where do you want to export the file
     path => "/data/foo.csv"
    }
}
```

You need to reach out to your Openbridge team so they can provision your private API for you.

### Step 4: Save Your Config

You will want to store your configs in a easy to remember location. You should also name the config in a manner that reflects the data resident in the CSV file. Since we are using `sales.csv` we saved our config like this: `/Users/bob/datastash/configs/sales.conf`. We will need to reference this config location in the next section.

The final config will look something like this:

```bash
####################################
# An input enables a specific source of
# events to be read by Logstash.
####################################

input {
  file {
     # Set the path to the source file(s)
     path => "/data/sales.csv"
     start_position => "beginning"
     sincedb_path => "/dev/null"
  }
}

####################################
# A filter performs intermediary processing on an event.
# Filters are often applied conditionally depending on the
# characteristics of the event.
####################################

filter {

 csv {

   # The CSV filter takes an event field containing CSV data,
   # parses it, and stores it as individual fields (can optionally specify the names).
   # This filter can also parse data with any separator, not just commas.

  # Set the comma delimiter
    separator => ","

  # We want to exclude these system columns
    remove_field => [
    "message", "host", "@timestamp", "@version", "path"
    ]

  # Define the layout of the input file
    columns => [
    "Sku","Name","SearchKeywords","Main","Price","ID","Brands"
    ]
  }

  # The mutate filter allows you to perform general
  # mutations on fields. You can rename, remove, replace
  # and modify fields in your events

  # We need to set the target column to "string" to allow for find and replace
  mutate {
    convert => [ "Sku", "string" ]
  }

  # Find and remove backslashes, question marks, equals and hashes from the target column. These are characters we do not want in our column
  mutate {
     gsub => [ "Sku", "[\\?#=]", "" ]
  }

  # Strip extraneous white space from records
  mutate {
     strip => [ "Sku","Name","SearchKeywords","Main","Price","ID","Brands"
     ]
  }

  # Set everything to lowercase
  mutate {
     lowercase => [ "Sku","Name","SearchKeywords","Main","Price","ID","Brands"
     ]
  }
}

####################################
# An output sends event data to a particular
# destination. Outputs are the final stage in the
# event pipeline.
####################################

output
{
  # Sending the contents of the file to the event API
  http
  {
    # Put the URL for your HTTP endpoint to deliver events to
    url => "https://myapi.foo-api.us-east-1.amazonaws.com/dev/events/teststash?token=774f77b389154fd2ae7cb5131201777&sign=ujguuuljNjBkFGHyNTNmZTIxYjEzMWE5MjgyNzM1ODQ="
    # Leave the settings below untouched.
    http_method => "post"
    format => "json"
    pool_max => "10"
    pool_max_per_route => "5"
  }
}
```

# How To Run

With your `sales.csv`config file saved to `/Users/bob/datastash/configs/sales.conf` you are ready to stream your data!

There are two things that Data Stash needs to be told in order to run.

1. Where to find your source CSV file (`/Users/bob/csv/mysalesdata`)
2. The location of the the config file (`/Users/bob/datastash/configs`)

You tell Data Stash where the file and config are via the `-v` or `volume` command in Docker. In our example your CSV is located on your laptop in this folder: `/Users/bob/csv/mysalesdata`. This means we put that path into the first `-v` command. Internally Data Stash defaults to `/data` so you can leave that untouched. It should look like this:

```bash
-v /Users/bob/csv/mysalesdata:/data
```

In our example you also saved your config file on you laptop here: `/Users/bob/datastash/config`. Data Stash defaults to looking for configs in `/config/pipeline` so you can that untouched:

```bash
-v /Users/bob/datastash/configs:/config/pipeline
```

Lastly, we put it all together so we can tell Data Stash to stream the file. Here is the command to run our Docker based Data Stash image:

```bash

 docker run -it --rm \
 -v /Users/bob/csv/mysalesdata:/data \
 -v /Users/bob/datastash/configs:/config/pipeline \
 openbridge/ob_datastash \
 datastash -f /config/pipeline/sales.conf
```

# Notes

## Processing A Folder Of CSV Files

In the example below we used a wildcard `*.csv` to specify processing all sales CSV files in the directory.

`path => "/the/path/to/your/*.csv"`

For example, if you had a file called `sales.csv`, `sales002.csv` and `sales-allyear.csv` using a wildcard `*.csv` will process all of them. I

Please note, using a `*.csv` assumes all files have the same structure/layout. If they do not, then you can be streaming disjointed data sets which will likely fail when it comes time to loading data to your warehouse.

## Performance
If you are processing very large CSV files that have millions of records this approach can take awhile to complete. Depending on the complexity of the filters, you can expect about 1000 to 3000 events (i.e., rows) processed per minute. A CSV with 1,000,000 rows might take anywhere from 5 to 8 hours to complete.

We limit the requests to 100 per second, so the max # of transactions possible in a minute would be 6000. At a rate of 6000 processing a 1M record CSV file would take close to 3 hours.

You might want to explore using the Openbridge SFTP or SCP options for processing larger files.

# Versioning

Docker Tag | Git Hub Release | Logstash | Alpine Version
---------- | --------------- | -------- | --------------
latest     | Master          | 5.5.2    | 3.6

# Reference

We leverage Logstash as the underlying application. Logstash is pretty cool and can do a lot more than just processing CSV files:

- <https://www.elastic.co/products/logstash>

CSV files should follow RFC 4180 standards/guidance to ensure success with processing

- <https://www.loc.gov/preservation/digital/formats/fdd/fdd000323.shtml>
- <https://tools.ietf.org/html/rfc4180>

This images is used for virtualizing your data streaming using Docker. If you don't know what Docker is read "[What is Docker?](https://www.docker.com/what-docker)". Once you have a sense of what Docker is, you can then install the software. It is free: "[Get Docker](https://www.docker.com/products/docker)". Select the Docker package that aligns with your environment (ie. OS X, Linux or Windows). If you have not used Docker before, take a look at the guides:

- [Engine: Get Started](https://docs.docker.com/engine/getstarted/)
- [Docker Mac](https://docs.docker.com/docker-for-mac/)
- [Docker Windows](https://docs.docker.com/docker-for-windows/)

# TODO

- Create more sample configs, including complex wrangling examples.

# Issues

If you have any problems with or questions about this image, please contact us through a GitHub issue.

# Contributing

You are invited to contribute new features, fixes, or updates, large or small; we are always thrilled to receive pull requests, and do our best to process them as fast as we can.

Before you start to code, we recommend discussing your plans through a GitHub issue, especially for more ambitious contributions. This gives other contributors a chance to point you in the right direction, give you feedback on your design, and help you find out if someone else is working on the same thing.

# License

This project is licensed under the MIT License - see the <LICENSE> file for details
