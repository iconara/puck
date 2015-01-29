# Puck

[![Build Status](https://travis-ci.org/iconara/puck.png?branch=master)](https://travis-ci.org/iconara/puck)

Puck takes your app and packs it along with all your gems and a complete JRuby runtime in a standalone Jar file that can be run with just `java -jar …`

## Installation

Add `puck` and `jruby-jars` to your `Gemfile`, preferably in a group, like this:

    group :development do
      gem 'puck'
      gem 'jruby-jars', '= 1.7.18'
    end

Make sure you specify a specific version of JRuby, and that it's the same as the one you're using locally. If you don't want to depend on `jruby-jars` for some reason there are ways to specify a path to `jruby-complete.jar`, see below for instructions.

## Requirements

Puck uses Bundler to figure out your gem dependencies, so if you're not using Bundler, Puck will not work.

Puck also requires you to specify the version of JRuby you want to bundle. The easiest way to do that is to add `jruby-jars` as a dependency, as described above, or provide your own `jruby-complete.jar`, as described below.

## Usage

You can use Puck either from the command line, or from your own code, for example in a `Rakefile`. See below for examples, and configuration.

Once you have a Jar file you can run your application like this:

    java -jar path/to/app.jar name-of-bin-script arg1 arg2

where `name-of-bin-script` is the name of a file from your app's `bin` directory. Any subsequent arguments will be passed to this script as if it was called directly from the command line. Everything your application needs to run will be included in the Jar, all gems and a complete JRuby runtime.

Puck also exposes all gem's bin files, as well as JRuby's, so if you have Pry among your (included) gems you can do this

    java -jar path/to/app.jar pry

to get a Pry session that can access your application's code.

### Creating a Jar from the command line

Just run `puck` and it build a Jar file from your app. The Jar will be placed in a directory called `build` in your application's root directory.

### Creating a Jar with Rake

Probably the best way to use Puck is to create a Rake task:

```ruby
task :dist do
  Puck::Jar.new.create!
end
```

As you can see the code to create a Jar file is tiny, you can easily integrate this with other tools like Thor or your custom build toolchain.

### Configuration

Puck has some sane defaults, and let's you override most of them. It will determine the name of your application from the current working directory (which will be the directory containing your `Rakefile` if you run it from a Rake task) and it will include all files in `bin` and `lib` automatically.

If you want to include files that are not in `bin` or `lib` you can pass in the `:extra_files` option:

```ruby
Puck::Jar.new(extra_files: Dir['config/*.yml']).create!
```

or using the command line:

```
puck --extra-files config/*.yml
```

There are a couple more options that you can set (check the [API documentation for `Puck::Jar#initialize`](http://rubydoc.info/github/iconara/puck/master/Puck/Jar#initialize-instance_method) for full documentation):

* `:gem_groups`: the groups from your `Gemfile` to include, defaults to `:default` (which is all gems that aren't in an explicit group). Don't include the group that contains `puck` and `jruby-jars`.
* `:app_dir`: your application's root directory, useful to set if it isn't the current working directory (and you're not using Rake).
* `:app_name`: the name of your application, it defaults to the name of the current working directory (and if you change that you don't need to change this too, you only need this option if you want a different name than the base directory's).
* `:build_dir`: defaults to `build`, but if you want the Jar file to end up somewhere else you can change it with this option.
* `:jruby_complete`: if you don't want to depend on the `jruby-jars` gem for some reason you can provide the path to your own `jruby-complete.jar`

They can also be specified on the command line (e.g. `puck --build-dir dist`).

## Gotchas

### Bundler

You can't have `require 'bundler'` or `require 'bundler/setup'` or anything else that references Bundler in your code.

Even if Puck uses Bundler to determine which gems to pack into the Jar it doesn't pack Bundler. Bundler is extremely opinionated, and assumes that it has full control, so creating an environment where it can run is not easy (just see the tests for this project to get an idea of what lengths you need to go to to get a clean environment to load Bundler). Bundler is also not need since the environment in the Jar is frozen – there are no dependencies to resolve or Gem paths to set up. Bundler, just like Puck, is a build time tool that shouldn't be required at run time.

Future versions of Puck may change this and make `require 'bunder/setup'` work, even though Bundler is not included, just to make it easier to run your code outside of the Jar – in JRuby using `require 'bundler/setup'` is many, many times faster than doing `bundle exec …` since it doesn't start an extra process.

### I get “Cannot run program "ant"”

You need to install [Ant](http://ant.apache.org/), most systems with a JDK come with Ant already installed, so the `ant` integration in JRuby seems to assume that it's always installed. `brew install ant`, `yum install ant` or `apt-get install ant` should all work.

Puck uses Ant primarily for its easy-to-use ZIP file merging abilities. Just like Puck, Ant is only a build-time dependency and is not included in artifact.

## Answers

### Why not just use Warbler?

I've found Warbler to be opinionated in an unhelpful way. For example, if you have a `config.ru` in your application's root directory but don't want to create a War file you need to monkeypatch two classes, one of them seemingly unrelated to War files.

If Warbler works for you, you should continue using it.

### The Jar file is huge, is there something I can do to slim it down?

Short answer: probably not.

The JRuby runtime with all its dependencies clocks in at 20 MiB, you could probably slim it down a little bit by removing the 1.8 standard library, but apart from that you should probably leave it. Your gems also take up quite a lot of space, but usually you don't notice because they're tucked away in some directory that you never see. The gems are bundled as-is and include everything that the gem author thought necessary to include, tests, documentation, etc. You can probably strip this, but it's included by default because many gems do weird things (I'm looking at you jruby-openssl).

Also, you're not going to put it on a floppy, you're going to send it over a network that handles megabytes per second, it's probably ok that you app is 50 MiB.

### Will it work with Rails?

I have no idea. Puck should be able to package anything that has a bin file that starts it, but Rails makes a lot of assumptions. Try it (and report back), but if it doesn't work you're probably better off with Warbler. Puck wasn't designed with Rails in mind, it was designed primarily for headless services, but it runs Rack applications just fine, the integration tests package a Rack app, launches it with Puma and throws a request at it to make sure it works.

## Copyright

Copyright 2013-2015 Theo Hultberg/Iconara

_Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License You may obtain a copy of the License at_

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

_Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License._
