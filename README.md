# Data Stash - Event API Client
Data Stash can ingest data from different data sources simultaneously, transform them, and then sends them to the Openbridge Events API.

# How It Works
Data Stash is based on a premise of inputs, filters and outputs.
 * **Inputs**: Your data sources.
 * **Filters**: Pre-processing your data prior to delivery to the output
 * **Outputs**: Openbridge REST API Webhooks

# Getting Started
Data Stash is neatly packaged into a Docker image so you can run this on your local laptop or deploy it to a server.
## Install
The first step is to build or pull the image:
```docker
docker build -t openbridge/ob_datastash .
```
or simply pull it from Docker Hub:
```docker
docker pull openbridge/ob_datastash:latest
```

## Example: Streaming CSV Files
Data Stash can take a CSV file and break each record into a streamed "event". These events are delivered to an Openbridge API for import into your target warehouse.

There are a couple uses cases around CSV files:

 * **Static Files**: You have exports from a system that you want to load to your data warehouse. Data Stash will process the exported source files and stream the contents of the file until it reaches the end.
 * **Dynamic Files**: You have a file that continually has new rows added. Data Stash will process changing files and stream new events as they are appended to a file.

In this example we have a static CSV file called `sales.csv` that we want to process.

## Configuration File
To run Data Stash you need to define a config file. Each config file is comprised of three parts; input, filter and output.

### Step 1: Define Your Input
The principle part of the input is setting the `path =>` to your file(s). In the example below we used a wildcard `*.csv` to specify processing all sales CSV files in the directory. For example, if you had a file called `sales.csv`, `sales002.csv` and `sales-allyear.csv` using a wildcard `*.csv` will process all of them. If you have a specific file you want to process then you can just put the name in like this `path => "/the/path/to/your/sales.csv"`

#### Example
You have a folder on your laptop `/Users/bob/csv/mysalesdata` with `sales.csv`.

Data Stash uses a default directory called `/data`. In the Data Stash config you will use the `/data` in the file path as a default.  When you run Data Stash you will tell it to map your laptop directory `/Users/bob/csv/mysalesdata` to the `/data`. This means anything in your laptop directory will appear exactly the same way inside `/data`.

See the "How To Run" section for more details on this mapping.

```bash
 input {
   file {
      path => "/data/*.csv"
      start_position => "beginning"
      sincedb_path => "/dev/null"
   }
 }
```

 ### Step 2: Define Your Schema
This is where you define your filter. For a CSV file the filter is focused on setting the schema of the CSV and removal of system generated columns.  

* The `separator => ","` defines the delimiter.
* The removal of system generated columns is done via `remove_field => [ "message", "host", "@timestamp", "@version", "path" ]`
* If you CSV file has a header row, then you can set `autodetect_column_names => "true"` and `autogenerate_column_names => "true"` to leverage those values when processing the file.

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
If your CSV does **not** have a header in the file you need to provide context about the target source file. You need to supply the header to the application `columns => [Sku,Name,SearchKeywords,Main,Price,ID,Brands]`
```bash
  filter {
    csv {
       separator => ","
       remove_field => [ "message", "host", "@timestamp", "@version", "path" ]
       columns => [Sku,Name,SearchKeywords,Main,Price,ID,Brands]
    }
  }
```

 ### Step 3: Define Your Output Destination
 The output defines the delivery location for all the records in your CSV(s). Openbridge will generate a API endpoint which you use in the `url => ""`.

 The delivery API would look like this `url => "https://myapi.foo-api.us-east-1.amazonaws.com/dev/events/teststash?token=774f77b389154fd2ae7cb5131201777&sign=ujguuuljNjBkFGHyNTNmZTIxYjEzMWE5MjgyNzM1ODQ="`
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

 You need to reach out to your Openbridge team so they can provision your private API for you.

### Save Your config
You will want to store your configs in a easy to remember location. You should also name the config in a manner that reflects the data it reflects. In our example it looks like this: `/Users/bob/datastash/configs/sales.conf`

We will need to reference this config in the next section.

# How To Run
With your config file defined and your `sales.csv` file ready to be streamed you can run the Data Stash application.

There are two things that Data Stash needs to be told.
 1. Where to find your CSV file
 2. The location of the the config file

You tell Data Stash these two things via the `-v` or volume command in Docker. As we already discussed your CSV is located on your laptop in this folder: `/Users/bob/csv/mysalesdata` so we put that into the first `-v` command. Data Stash defaults to `/data` so you can leave that untouched. It should look like this

```bash
-v /Users/bob/csv/mysalesdata:/data
```

You saved your config file on you laptop here `/Users/bob/datastash/config`. Data Stash defaults to looking for configs in `/config/pipeline` so you can that untouched

```bash
-v /Users/bob/datastash/configs:/config/pipeline
```

```bash
 docker run -it --rm \
 -v /Users/bob/csv/mysalesdata:/data \
 -v /Users/bob/datastash/configs:/config/pipeline \
 openbridge/ob_datastash \
 datastash -f /config/pipeline/sales.conf
```

# Reference
We leverage Logstash as the underlying application. Logstash is pretty cool and can do a lot more than just processing CSV files:
 * https://www.elastic.co/products/logstash

CSV files should follow RFC 4180 standards/guidance to ensure success with processing
 * https://www.loc.gov/preservation/digital/formats/fdd/fdd000323.shtml
 * https://tools.ietf.org/html/rfc4180

This images is used for virtualizing your data streaming using Docker. If you don't know what Docker is read "[What is Docker?](https://www.docker.com/what-docker)". Once you have a sense of what Docker is, you can then install the software. It is free: "[Get Docker](https://www.docker.com/products/docker)". Select the Docker package that aligns with your environment (ie. OS X, Linux or Windows). If you have not used Docker before, take a look at the guides:

 - [Engine: Get Started](https://docs.docker.com/engine/getstarted/)
 - [Docker Mac](https://docs.docker.com/docker-for-mac/)
 - [Docker Windows](https://docs.docker.com/docker-for-windows/)

# Versioning
| Docker Tag | Git Hub Release | Logstash | Alpine Version |
|-----|-------|-----|--------|
| latest | Master | 5.5.2 | 3.6 |


# TODO
* Create more sample configs, including complex wrangling examples.

# Issues
If you have any problems with or questions about this image, please contact us through a GitHub issue.

# Contributing
You are invited to contribute new features, fixes, or updates, large or small; we are always thrilled to receive pull requests, and do our best to process them as fast as we can.

Before you start to code, we recommend discussing your plans through a GitHub issue, especially for more ambitious contributions. This gives other contributors a chance to point you in the right direction, give you feedback on your design, and help you find out if someone else is working on the same thing.

# License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details
