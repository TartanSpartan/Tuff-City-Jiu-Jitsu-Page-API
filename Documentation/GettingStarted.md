# Getting Started

## System Dependencies

The API uses Ruby v3.4.2 and Rails v8.0.2 (I recommend using RVM to leverage those versions on your development machine), with Postgres16. The React client, the Postgres database and the Rails API platforms can easily be run on the same development machine using a fairly standard setup. However I test my home network configuration by deploying each on different machines (the Postgres instance is on Docker and I may dockerize the other two in production mode) using a Nginx reverse proxy configuration. 

## Configuration: Development Mode (Multiple Machines)

* Clone the repository to your local machine e.g. via `git clone git@github.com:TartanSpartan/Tuff-City-Jiu-Jitsu-Page-API.git`

* Please refer to [credentials.yml.example](credentials.yml.example) here, and the .env.example in the React repository for a general view of the required environment variables should you wish to duplicate my exact setup

* For some of the commands and directories below I assume a Debian/Ubuntu type of OS, please modify accordingly for your OS of choice

* After installing nginx, you will want to edit the `/etc/nginx/sites-enabled/default` file on each respective machine for the client and API; the API is described below, and see information about the client's configuration [here](https://github.com/TartanSpartan/Tuff-City-Jiu-Jitsu-Page-Client/tree/main/Documentation/GettingStarted.md)

* The client serves a URL (e.g. https://myurl.org) on a private tailnet (you must set this up for yourself, e.g. via Headscale or Tailscale) which will interact with the API, which represents another node on that tailnet

* The nginx default sites-enabled file for the API defines one location `/` which will act as a proxy_pass for the server running on local IP address e.g. http://localhost:3000

* The standard api/v1/ Rails endpoint routes the project defines are then accessed like https://myurl.org/api/v1/belts/ allowing you to inspect the JSON sets for each

* If you are running the full stack on the same machine, run the React server in one terminal and the Rails server in another and follow the instructions below (which also apply for initial installation of dependencies, and database creation, for the multiple machines scenario)

## Initial Setup: Running It Locally

* Run `bundle install` to pull in the gem dependencies for the project. Add new gems as you please but remember to run bundle install afterwards each time before starting the development server again

* To edit your own credentials file, run `EDITOR=nano rails credentials:edit` (and replace `nano` with whichever editor you prefer) 

* My OAuth implementation so far relies on Google as a means to log users in, but there will be other provider options in the future. For now as a first step, you will need to use the [Google Client console](https://console.cloud.google.com) to generate the `google_client_id` and `google_client_secret` variables for config/credentials.yml.enc

* Please see [guides such as this](https://www.balbooa.com/help/gridbox-documentation/integrations/other/google-client-id) for more information on how to achieve that

## Database Instantiation and Server Setup

* With the Postgres16 instance set up with appropriate credentials and port to connect to Rails, then to initiate the database, run `rails db:create`. Run `rails db:migrate` to have the pending database migrations occur

* Do not run `rails db:seed` yet, because I still need to implement some controllers and models from older versions to allow the database to be fully seeded, but this will be done soon; for now I am relying instead on manual creation of database entries from the frontend and/or the Rails Console

* If your database needs to be started over for whatever reason, run `rails db:drop`

* Finally, run `rails s` to initiate the server

## Testing

* I am focusing on Rspec to test my controllers and models. To perform all tests, simply run `rspec`. 

* To perform a specific file's test, run e.g. `rspec spec/requests/sessions/omniauth_spec.rb`.

* To target a test on a specific line of the file, run `rspec spec/path/to/your_file_spec.rb:line_number` where `line_number` is e.g. 40

I will cover deployment instructions, and any required external services, when I have achieved those milestones myself.