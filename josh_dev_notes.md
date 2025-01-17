# josh's ongoing dev notes

PR associated with this work: [@mastodon, Help the test harness run more speedily #29992](https://github.com/mastodon/mastodon/pull/29992)

[Public version of this file you're reading right now](https://gist.github.com/josh-works/63e57445035d1dd3beb604114ea2caac)

big summary of what I'm hoping to do, especially because Vladimir Dementyev, in the time since I opened this PR, did a rails conf talk of how he did/would profile this app!!!!

here's the talk: [ RailsConf 2024 - From slow to go: Rails test profiling hands-on by Vladimir Dementyev (with mastodon!!!!)](https://www.youtube.com/watch?v=PvZw0CnZNPc)

he doesn't seem to have made a PR, though. So nearly all, or actually all, these changes are directly a result of him _doing the work_ but possibly not committing it all.

- [x] disable simplecov most of the time (proven effective, was costing 5 seconds at least every time tests were run)
- [x] debugger gem getting called all over the place (fixed by setting require: false in Gemfile for that gem)
- [ ] i18n load path, speeds up boot time, handled in bootsnap
- [ ] paperclip
- [x] webpacker: cache_manifest: true (added, seen in the profiling but not directly tested in test timing)
- [ ] sidekiq:inline test mode, but only for tests that need it instead of all the time. (saving 40% of spec/requests time?)
-

## Thursday, April 18, 2024

lets audit/profile + speedrun?

Just `git clone` and `rbenv install 3.2.3` and `bundle install`. Contribution guidelines are sorta spotty on running the app locally?

```
# fork it
git clone git@github.com:josh-works/mastodon.git
cd mastadon.git
rbenv install 3.2.3
bundle install
RAILS_ENV='test' bundle exec rails db:setup
b rspec spec
```

To figure out what counts as a good change, lets look at recently merged PRs:

https://github.com/mastodon/mastodon/pulls?q=is%3Apr+is%3Amerged+sort%3Aupdated-desc

filters: `is:pr is:merged sort:updated-desc `

Found a merged PR, looking at the `actions` tab, the `test` step looks like.... 31 minutes? Doesn't seem right, but time within github actions is still a bit opaque to me. I know ultimately I'll need to understand it well enough to make things way faster

https://github.com/mastodon/mastodon/actions/runs/8668161596

My machine is still installing ruby 3.2.3, so I don't have anything running locally yet. NBD.

OK, running tests, everything is failing:

```
  45) Admin::StatusesController GET #index with a valid account returns http success
      Failure/Error: src, integrity = current_webpacker_instance.manifest.lookup!(name, type: :javascript, with_integrity: true)

      ActionView::Template::Error:
        Webpacker can't find public.js in /Users/joshthompson/software_projects/mastodon/public/packs-test/manifest.json. Possible causes:
        1. You want to set webpacker.yml value of compile to true for your environment
           unless you are using the `webpack -w` or the webpack-dev-server.
        2. webpack has not yet re-run to reflect updates.
        3. You have misconfigured Webpacker's config/webpacker.yml file.
        4. Your webpack configuration is not creating a manifest.
        Your manifest contains:
        {
        }
      # ./lib/webpacker/helper_extensions.rb:5:in `javascript_pack_tag'
```

something with webpacker. also test logs showing TONS of stuff like:

```
Cache generate: rails_settings_cached/63381685ff04b23fd115d853efac4ba3/registrations_mode ({:compress=>false, :compress_threshold=>1024})
Cache write: rails_settings_cached/63381685ff04b23fd115d853efac4ba3/registrations_mode ({:compress=>false, :compress_threshold=>1024})
Cache read: rails_settings_cached/63381685ff04b23fd115d853efac4ba3/reserved_usernames ({:compress=>false, :compress_threshold=>1024})
Cache generate: rails_settings_cached/63381685ff04b23fd115d853efac4ba3/reserved_usernames ({:compress=>false, :compress_threshold=>1024})
Cache write: rails_settings_cached/63381685ff04b23fd115d853efac4ba3/reserved_usernames ({:compress=>false, :compress_threshold=>1024})
Cache read: rails_settings_cached/63381685ff04b23fd115d853efac4ba3/reserved_usernames ({:compress=>false, :compress_threshold=>1024})
```

Stopping the tests, gonna try to get a single passing test:

```
b rspec ./spec/controllers/admin/trends/statuses_controller_spec.rb
```

once we have a single passing test, I'll... see if I can get most tests passing. I'll check the github action scripts to see what I'm missing.

Found [this issue](https://github.com/rails/webpacker/issues/1047), the fix seems to be:

```
NODE_ENV=test RAILS_ENV=test bundle exec rails webpacker:compile
```

yep, something with `yarn`. my yarn version might be out of date, of course.

running `yarn` seems to be doing something, but probably not the right thing.

```
nvm install 20.12.2
```

That ran, lets re-try the webpacker compile. Nope.

Yarn things.

```
npm install --global yarn
```

Found https://docs.joinmastodon.org/dev/setup/

Here's the stuff it took to get me to a locally running server 🤞🏼

```
gem install foreman
RAILS_ENV='development' bundle exec rails db:setup
yarn install
NODE_ENV=development RAILS_ENV=development bundle exec rails webpacker:compile
foreman start
```

lets see what I get here. Might get other/more helpful errors around javascript packages, and I "should" be able to run the app locally.

https://github.com/mastodon/mastodon/issues/8853 was helpful/instructive

Took a bit to get it all happy, but we're compiling in development right now...

and it works. Got a server running, rendering http://localhost:3000/, redirects to mastadon home, http://localhost:3000/explore, huzzah. Test time.

If that works I'll flip it to `test` and re-do it, then re-run tests.

```
NODE_ENV=test RAILS_ENV=test bundle exec rails webpacker:install
NODE_ENV=test RAILS_ENV=test bundle exec rails webpacker:compile
```

success?!?!?!

Lots of whackamole.

That didn't work, modified the webpacker.yml test::compile to `true`, but also started the webpack dev server via `w`

still lots of errors. brutal.

```
 ActionView::Template::Error:
       Webpacker can't find public.js in /Users/joshthompson/software_projects/mastodon/public/packs-test/manifest.json. Possible causes:
       1. You want to set webpacker.yml value of compile to true for your environment
          unless you are using the `webpack -w` or the webpack-dev-server.
       2. webpack has not yet re-run to reflect updates.
       3. You have misconfigured Webpacker's config/webpacker.yml file.
       4. Your webpack configuration is not creating a manifest.
       Your manifest contains:
       {
       }
```

oh hell yeah, that worked, I restarted the webpack dev server, re-ran the tests, and we have thousands of passing specs!!!!!

```
 NODE_ENV=test RAILS_ENV=test bundle exec rspec
Run options: exclude {:search=>true, :type=>#<Proc: ./spec/rails_helper.rb:53>}

Randomized with seed 5687
 557/5540 |======== 10 =========>
```

NOOOOOOW we wait. This is the first 'gold standard' single run of the tests, I estimate it'll take up to 30 min.

I'm streaming the dev logs, the lines-per-minute is way higher than open street map. I'll still submit a PR initially turning off logging in the test environment, so I can have my own PR to attach the rest of my notes to. Maybe that'll always be my first step.

1. count the lines of logs generated per test run. oh look now you have initial timing information! (120 lines of logging per second, or 142k lines of logs across 1200 seconds)
2. turn off logging (`:warn`), submit PR.
3. by now I/you have a little more timing info, too. Will have run `--verbose` mode, have an idea of an assertions/second count and total time.

the output makes me think 5500 assertions. maybe it's files? not anywhere close to the number of assertions I'd expect in a project this size.

while waiting for the tests, I open the first PR turning off logging:

https://github.com/mastodon/mastodon/pull/29992

The tests finished, so lets see the length of the logs, and various diagnostics.

`wc -l log/test.log` => 165,171 lines

doesn't seem like that many lines.

```
Finished in 20 minutes 34 seconds (files took 16.46 seconds to load)
5540 examples, 12 failures
```

here's all the errors, in case I want to fix them later, besides the obvious `brew install ffmpeg` or something

```

  1) MediaAttachment mp3 with large cover art detects it as an audio file
     Failure/Error: raise Paperclip::Errors::CommandNotFoundError, 'Could not run the `ffmpeg` command. Please install ffmpeg.'

     Paperclip::Errors::CommandNotFoundError:
       Could not run the `ffmpeg` command. Please install ffmpeg.
     # ./lib/paperclip/image_extractor.rb:44:in `rescue in


```

ok, error with `brew install ffmpeg`, need to perhaps install `xcode-select`, I thought I already had it.

not that I really need these tests to pass, but I do like green test suites.

Lets look at timing:

```
Finished in 20 minutes 34 seconds (files took 16.46 seconds to load)
5540 examples, 12 failures
```

That seems so slow, but with a fast load time. This is on par with rails apps I've worked on. the rails apps in question had between 3-5 full-time engineers, and were embedded within engineering teams of 30-60 engineers. This isn't a "slow" test suite, by the standards of slow enterprise test suites, but it's on par for plenty of 'normal' rails test suites.

First thing I'll do will be turn off my wifi and re-run the tests, JUST TO MAKE SURE IT ABSOLUTELY WORKS. I've not even peeked to see if VCR is in the gemfile... once xcode select is done installing. lol.

Since it takes 20 minutes locally, I remember now seeing NOT 20 minutes when looking on the github actions build process.

https://github.com/mastodon/mastodon/actions/runs/8742139749/job/23989707460?pr=29173

looks like the tests are run in groups, like `bundle exec rake spec:system`

but sometimes it says it runs `bin/rspec` and _that_ finishes in 5m53s. So fast. hm.

Anyway, xcode-select is installed, and re-installing ffmpeg and... gosh another long installation process.

[...]

ffmpeg finally finished, took like, lets re-run a single previously failing ffmpeg test, just for fun:

```
rspec ./spec/models/media_attachment_spec.rb:214 --profile
```

that worked.

lets re-do the whole suite, make sure the logs are turned off now:

```
time RAILS_ENV=test b  rspec --profile
```

looks like it's working great, and there's no more logs getting written.

Confirmed, re-enabling logging, and all is good. I don't need to be running `webpack-dev-server` for tests, btw. Just local development.

Now running the tests with `--profile` turned on, and I'm going to turn off wifi next.

I'm gonna let the whole suite run, just to see if the ffmpeg thing is fixed.

Assuming all is green, the order of operations:

- turn off wifi, make sure test suite is green, address if not
- add `puts` statement to 2 or 3 factories, so I can see every time they're run (`user`, `account`), perhaps breaking the user or account facotyr
- install ruby-test-prof tool, run a diagnostic

Just nudged [https://github.com/openstreetmap/openstreetmap-website/pull/4708](https://github.com/openstreetmap/openstreetmap-website/pull/4708) along - it's cool, the maintainer of the OSM project also has a Mastadon account - I wonder if I can get him to review both PRs. lol.

```
Randomized with seed 28034
/Users/joshthompson/software_projects/mastodon/spec/services/remove_featured_tag_service_spec.rb:32: warning: [WARNING] `have_enqueued_sidekiq_job()` without arguments default behavior will change in next major release. Use `have_enqueued_sidekiq_job(no_args)` to maintain legacy behavior. More available here: https://github.com/wspurgin/rspec-sidekiq/wiki/have_enqueued_sidekiq_job-without-argument-default-behavior
 5540/5540 |========================================= 100 ==========================================>| Time: 00:20:48

Top 10 slowest examples (60.25 seconds, 4.8% of total time):
  Profile I can change my account
    7.54 seconds ./spec/features/profile_spec.rb:23
  MediaAttachment mp3 with large cover art extracts thumbnail
    6.18 seconds ./spec/models/media_attachment_spec.rb:222
  MediaAttachment mp3 with large cover art sets meta for the duration
    6.15 seconds ./spec/models/media_attachment_spec.rb:218
  MediaAttachment mp3 with large cover art gives the file a random name
    5.99 seconds ./spec/models/media_attachment_spec.rb:226
  MediaAttachment mp3 with large cover art detects it as an audio file
    5.96 seconds ./spec/models/media_attachment_spec.rb:214
  blocking domains through the moderation interface when editing a domain block presents a confirmation screen before suspending the domain
    5.95 seconds ./spec/features/admin/domain_blocks_spec.rb:88
  Severed relationships page GET severed_relationships#index returns http success
    5.81 seconds ./spec/features/severed_relationships_spec.rb:17
  Auth::SessionsController POST #create when using two-factor authentication with OTP enabled as second factor when repeatedly using an invalid TOTP code before using a valid code does not log the user in, sets a flash message, and sends a suspicious sign in email
    5.75 seconds ./spec/controllers/auth/sessions_controller_spec.rb:266
  Profile I can view Annes public account
    5.48 seconds ./spec/features/profile_spec.rb:17
  blocking domains through the moderation interface when suspending a subdomain of an already-silenced domain presents a confirmation screen before suspending the domain
    5.44 seconds ./spec/features/admin/domain_blocks_spec.rb:61

Top 10 slowest example groups:
  Profile
    6.51 seconds average (13.02 seconds / 2 examples) ./spec/features/profile_spec.rb:5
  Severed relationships page
    5.81 seconds average (5.81 seconds / 1 example) ./spec/features/severed_relationships_spec.rb:5
  blocking domains through the moderation interface
    5.17 seconds average (25.86 seconds / 5 examples) ./spec/features/admin/domain_blocks_spec.rb:5
  finding software updates through the admin interface
    4.05 seconds average (4.05 seconds / 1 example) ./spec/features/admin/software_updates_spec.rb:5
  Admin::Accounts
    3.84 seconds average (15.35 seconds / 4 examples) ./spec/features/admin/accounts_spec.rb:5
  Admin::Trends::Statuses
    3.83 seconds average (3.83 seconds / 1 example) ./spec/features/admin/trends/statuses_spec.rb:5
  Log in
    3.82 seconds average (11.47 seconds / 3 examples) ./spec/features/log_in_spec.rb:5
  email confirmation flow when captcha is enabled
    3.77 seconds average (3.77 seconds / 1 example) ./spec/features/captcha_spec.rb:5
  Admin::Statuses
    3.75 seconds average (3.75 seconds / 1 example) ./spec/features/admin/statuses_spec.rb:5
  Admin::Trends::Links
    3.73 seconds average (3.73 seconds / 1 example) ./spec/features/admin/trends/links_spec.rb:5

Finished in 20 minutes 48 seconds (files took 16.08 seconds to load)
5540 examples, 0 failures

Randomized with seed 28034
Coverage report generated for RSpec to /Users/joshthompson/software_projects/mastodon/coverage. 24715 / 27910 LOC (88.55%) covered.
RAILS_ENV=test bundle exec rspec --profile  793.44s user 418.39s system 95% cpu 21:09.07 total
```

I don't really care about the slowest tests yet, want to see what factories are humming along. 21 minutes total, zero failures, the `ffmpeg` thing is good to go.

---

### `puts` statements in `user` and `account` factories

it looks like many, many tests rely on a user and an account. But there's so few assertions/second, it feels like the time is being lost elsewhere. The passwords seem to be getting run through a hashing function:

```ruby
# spec/fabricators/user_fabricator.rb

Fabricator(:user) do
  account      { Fabricate.build(:account, user: nil) }
  email        { sequence(:email) { |i| p "user #{i}";"#{i}#{Faker::Internet.email}" } }
  password     '123456789'
  confirmed_at { Time.zone.now }
  current_sign_in_at { Time.zone.now }
  agreement true
end
```

but a peek in `schema.rb` shows that `user` requires an `encrypted password`

I'm gonna see if I can write that attribute directly with something like:

```ruby
Fabricator(:user) do
  account      { Fabricate.build(:account, user: nil) }
  email        { sequence(:email) { |i| p "user #{i}";"#{i}#{Faker::Internet.email}" } }
  encrypted_password     '123456789' # I want to change this string to whatever ruby hashes/salts this to, store it directly
  confirmed_at { Time.zone.now }
  current_sign_in_at { Time.zone.now }
  agreement true
end

```

to get a valid value:

```ruby
Fabricator(:user) do
  account      { Fabricate.build(:account, user: nil) }
  email        { sequence(:email) { |i| p "user #{i}";"#{i}#{Faker::Internet.email}" } }
  password     '123456789'
  confirmed_at { Time.zone.now }
  current_sign_in_at { Time.zone.now }
  agreement true

  after(:create) do |user|
    p user
  end
end
```

I'm watching thousands of users/accounts be created, btw. probably over 5000 of each, through the test run. OSM had 4000 accounts created in 7 min. this doesn't feel like its gonna matter. it's annoying how slow the whole suite is.

tests do run faster when I break every `create(:user)` call, perhaps.

HAH! The tests run in 2:15 when I break all the `user` calls. TWO MINUTES AND FIFTEEN SECONDS!!!!!

Finished in 1 minute 58.55 seconds (files took 12.51 seconds to load)
5540 examples, 3977 failures

So, almost every spec broke.

Seems to validate, though, looking at speeding up this portion of the process.

OK, tried bringing a hard-coded idea to the table, but I'm afraid validations are still running, so there's no speed improvement:

```ruby
# frozen_string_literal: true

Fabricator(:user) do
  account      { Fabricate.build(:account, user: nil) }
  email        { sequence(:email) { |i| p "user #{i}";"#{i}#{Faker::Internet.email}" } }
  password     '123456789'
  encrypted_password "$2a$04$jgn1Z.Qzn0vrDAPQn41x5u1Wt1/rdA7OGzXT9FIcUn1JlilxNUaLO"
  confirmed_at { Time.zone.now }
  current_sign_in_at { Time.zone.now }
  agreement true
end
```

if i didn't give a `password` value, no dice, of if it wasn't long enough, got a validations error.

The way to see, I suppose, would be to (oooh, a bunch of failures) do `p user.encrypted_password` a few different spots in the app, see if they're the given value or something different.

That could prove it didn't work, wouldn't prove it _did_ work.

Lol, OK, found this:

```ruby
# config/initializers/devise.rb

  # Limiting the stretches to just one in testing will increase the performance of
  # your test suite dramatically. However, it is STRONGLY RECOMMENDED to not use
  # a value less than 10 in other environments. Note that, for bcrypt (the default
  # encryptor), the cost increases exponentially with the number of stretches (e.g.
  # a value of 20 is already extremely slow: approx. 60 seconds for 1 calculation).
  config.stretches = Rails.env.test? ? 1 : 10
```

to make sure this controls the difficulty, I set that `1` to `20`, with the `puts` statement still in the factory, and it brought the tests to a screaming halt. Also sampling at 10, it's much faster. 14 is terrible, but moves slowly.

1 is the lowest available figure, not 0, not 0.1.

calling it here for tonight. Made good progress.

tomorrow, wifi off, figure out stack-prof, because this is an rspec suite, might be happier with some of the `let_it_be` type tooling

- https://test-prof.evilmartians.io/profilers/event_prof?id=rspec
- https://test-prof.evilmartians.io/recipes/let_it_be

the factory is saving different encrypted_password values:

```
➜  mastodon git:(speed_up_tests) ✗ time RAILS_ENV=test b  rspec spec/controllers/filters_controller_spec.rb
Run options: exclude {:search=>true, :type=>#<Proc: ./spec/rails_helper.rb:53>}

Randomized with seed 55846
"account 0"
"user 0"
"account 1"
"user 1"
"$2a$04$UIHnzPGZB4nsbrxCxZtZRe8i7oeuaP4XDdypXhIDFeX3mjQhXVpti"
"account 2"
"user 2"
"account 3"
"user 3"
"$2a$04$cl.FBSBV2z4TMAdh21ugBOTg9JmJqsCPPPmRb82FthAYzCkTztwBa"
Finished in 7.82 seconds (files took 10.08 seconds to load)
3 examples, 0 failures

Randomized with seed 55846
```

bummer.

## Sunday, April 28, 2024

```
RAILS_ENV=test bundle exec rspec --profile  790.51s user 421.22s system 94% cpu 21:28.54 total
```

21.5 minutes. it's _supposed_ to be 'high single digits', maybe it's bc I'm running this on a weak, old laptop. oh well, it's all relative.

## Monday, May 20, 2024

bleh lots of time passed.

Lets get a single sub-test to run. the `.dump` files getting written to `tmp/test_prof` seem related to errors, not valid results.

```
RAILS_ENV=test bundle exec rspec spec/controllers/auth/confirmations_controller_spec.rb
```

```
RAILS_ENV=test bundle exec rspec spec/controllers/auth/confirmations_controller_spec.rb --profile
```

better, but that's rspec profiling, lets get testprof working...

```
EVENT_PROF=sql.active_record  RAILS_ENV=test bundle exec rspec spec/controllers/auth/confirmations_controller_spec.rb
```

🤞🏼

Cool, got valid output, here's the new stuff:

```
[TEST PROF INFO] EventProf results for sql.active_record

Total time: 00:00.108 of 00:04.600 (2.36%)
Total events: 218

Top 5 slowest suites (by time):

Auth::ConfirmationsController (./spec/controllers/auth/confirmations_controller_spec.rb:5) – 00:00.108 (218 / 8) of 00:04.600 (2.36%)

```

Huzzah. This is meaningful. I still want a 'baby' result of something printed to `tmp/test_prof` but this is a start.

```
TEST_STACK_PROF=boot  RAILS_ENV=test bundle exec rspec spec/controllers/auth/confirmations_controller_spec.rb
```

This is another test type, straight from the docs, seeing if it works, look like it did.

Perf, generated a _much_ smaller .dump and .json file output, lets see how to read these things..

[http://www.quirkey.com/blog/2015/06/23/reading-in-the-stacks-understanding-stackprof/](http://www.quirkey.com/blog/2015/06/23/reading-in-the-stacks-understanding-stackprof/)

`gem install stackprof-remote` & `stackprof-cli tmp/test_prof/stack-prof-report-wall-raw-boot-1635313.dump`

that didn't work...

Oh, this uses `stackprof` under the hood, which has a reader included. https://github.com/tmm1/stackprof

```
stackprof tmp/test_prof/stack-prof-report-wall-raw-boot-1635313.dump
==================================
  Mode: wall(1000)
  Samples: 8626 (13.51% miss rate)
  GC: 743 (8.61%)
==================================
     TOTAL    (pct)     SAMPLES    (pct)     FRAME
      7788  (90.3%)        3913  (45.4%)     Kernel#require
      6279  (72.8%)         941  (10.9%)     Kernel#require_relative
      1049  (12.2%)         712   (8.3%)     Kernel.require
       590   (6.8%)         590   (6.8%)     (marking)
       181   (2.1%)         179   (2.1%)     Thread::Queue#pop
       169   (2.0%)         169   (2.0%)     (sweeping)
      5041  (58.4%)         167   (1.9%)     Kernel.require
        94   (1.1%)          86   (1.0%)     Kernel#load
        70   (0.8%)          70   (0.8%)     IO#wait
        66   (0.8%)          66   (0.8%)     RubyVM::InstructionSequence.compile
        93   (1.1%)          58   (0.7%)     Kernel.require_relative
       429   (5.0%)          56   (0.6%)     Module#class_eval
        52   (0.6%)          52   (0.6%)     File.realpath
        90   (1.0%)          50   (0.6%)     Module#module_eval
       407   (4.7%)          37   (0.4%)     Kernel.load
        43   (0.5%)          32   (0.4%)     String#gsub!

```

Excellent. Lets run this one more time, in tight succession:

```
$ time TEST_STACK_PROF=boot  RAILS_ENV=test bundle exec rspec spec/controllers/auth/confirmations_controller_spec.rb
stackprof tmp/test_prof/stack-prof-report-wall-raw-boot-1636578.dump
==================================
  Mode: wall(1000)
  Samples: 7754 (11.23% miss rate)
  GC: 639 (8.24%)
==================================
     TOTAL    (pct)     SAMPLES    (pct)     FRAME
      7033  (90.7%)        3490  (45.0%)     Kernel#require
      5444  (70.2%)         784  (10.1%)     Kernel#require_relative
      1054  (13.6%)         717   (9.2%)     Kernel.require
       544   (7.0%)         544   (7.0%)     (marking)
      4311  (55.6%)         167   (2.2%)     Kernel.require
       156   (2.0%)         154   (2.0%)     Thread::Queue#pop
       108   (1.4%)         108   (1.4%)     (sweeping)
        84   (1.1%)          84   (1.1%)     IO#wait
        80   (1.0%)          72   (0.9%)     Kernel#load
       101   (1.3%)          68   (0.9%)     Kernel.require_relative
        56   (0.7%)          56   (0.7%)     PG::Connection#exec_params
       397   (5.1%)          51   (0.7%)     Module#class_eval
        51   (0.7%)          51   (0.7%)     RubyVM::InstructionSequence.compile
        89   (1.1%)          47   (0.6%)     Module#module_eval
        43   (0.6%)          43   (0.6%)     File.realpath
        36   (0.5%)          36   (0.5%)     String#split
       426   (5.5%)          35   (0.5%)     Kernel.load
        30   (0.4%)          30   (0.4%)     Encoding.find
        47   (0.6%)          27   (0.3%)     Bootsnap::LoadPathCache::LoadedFeaturesIndex#initialize
        45   (0.6%)          27   (0.3%)     ActionDispatch::Routing::Mapper::Scope#each
      7106  (91.6%)          17   (0.2%)     Array#each

```

cool. `Kernel#require` being the biggest thing, and ~80% of the total time spent in the first 4 results tracks. (80/20)

It sampled 90 % of the frames, and perhaps spent 8.2% on garbage collection.

Now that we know how to view the results, lets profile something else.

[https://test-prof.evilmartians.io/recipes/tests_sampling](https://test-prof.evilmartians.io/recipes/tests_sampling)

now prepend `SAMPLE 10` to the next call?

`SAMPLE=10 TEST_STACK_PROF=1 RAILS_ENV=test bundle exec rspec spec/controllers`

Looking promising so far.

Lets do a larger thing. I cannot run the 1 gb dump file, so I'm gonna try re-running the whole thing with the `SAMPLE` envvar included: `SAMPLE=10 TEST_STACK_PROF=1 RAILS_ENV=test bundle exec rspec spec`

```
SAMPLE=10 RAILS_ENV=test bundle exec rspec spec
```

that's the way to go.

OK, getting some nice output. No obvious leads yet. I still am running `puts` statements in the `user` and `account` factory - when I intentionally break the user factory all tests go lightning fast (2:20 total run time) but tons of failures.

It seems like most of the time is being spent not in account/user creation. Just an intuition, watching the timing of the puts statements, tests passing (or failing) and tail'ing `log/test.log`.

I want a verbose mode. I want to know the tests are hanging out - some sort of 'current_file_test.rb` output would be handy.

## Thursday, May 23, 2024

I'm still teased by the memory that there was a 90% reduction in test run time when I 'simply' broke the user creation process. Obviously some of the tests would have exited early rather than finishing, but I'm still aware and curious, and the fact that I've still not locked down the users' password to something consistent across all user setups means Devise is still applying it's 'stretching' function to the password.

And in open street map's profile, I got 50% time savings with this same fix.

We can see that tons of app time is spent in `Kernal#require`, I wonder if that's what it would look like if Devise was eating all this time doing needless computational work.

Lets open up the devise gem and find that function.

```
$ bundle open devise
# 'mvim /Users/joshthompson/.rbenv/versions/3.2.3/lib/ruby/gems/3.2.0/gems/devise-4.9.4'
$ code /Users/joshthompson/.rbenv/versions/3.2.3/lib/ruby/gems/3.2.0/gems/devise-4.9.4
```

I can see where it passes the `stretch` value off to BCrypt

```ruby
# lib/devise/encryptor.rb
module Devise
  module Encryptor
    def self.digest(klass, password)
      if klass.pepper.present?
        password = "#{password}#{klass.pepper}"
      end
      ::BCrypt::Password.create(password, klass.stretches).to_s
    end
```

I wonder if I can pass no stretches. or 0. Looking at `BCRYPT::Password.create`...

```ruby
def create(secret, options = {})
  cost = options[:cost] || BCrypt::Engine.cost
  raise ArgumentError if cost > BCrypt::Engine::MAX_COST
  Password.new(BCrypt::Engine.hash_secret(secret, BCrypt::Engine.generate_salt(cost)))
end
```

So, if I keep up with the `break local gems for fun and profit` trend, lets see...

(btw, running tests without wifi, don't remember if I did it before, to make sure it's all good, I think that's the case)

All good without wifi. I'm getting somewhere with sidestepping the BCrypt::Engine calls.

When I dig into the above method. I've got it working, going to get home so I can run my laptop on wall power, so it'll go at full speed. This isn't gonna be my 90% fix, I don't think. But might be good for 50%, in theory. Currently I don't know how I would stub out one library's calls to another library.

(devise, calling BCrypt::Engine.hash_secret, every time a user is created. Perhaps a let_it_be block)

i'll look later. this was a fruitful exploration. I can hardcode values in the Bcrypt or Devise gem, locally, to simulate what it would be like if no computational cycles were spent doing that effort, and indeed tests seem faster.

Here's a small little benchmark, to see what comes up.

Also, setting log level to `debug` when doing this close analysis.

running just model tests, with & without stubbing the bcrypt calls, also seeing if anything shows up in testprof output:

```
# stubbed calls
time RAILS_ENV=test bundle exec rspec spec/models
Finished in 1 minute 41.29 seconds (files took 10.15 seconds to load)
1115 examples, 17 failures
RAILS_ENV=test bundle exec rspec spec/models  81.05s user 24.25s system 91% cpu 1:54.88 total
```

Then, bringing back bcrypt:

```
# not stubbed calls
time RAILS_ENV=test bundle exec rspec spec/models
Finished in 1 minute 40.81 seconds (files took 11.08 seconds to load)
1115 examples, 10 failures
RAILS_ENV=test bundle exec rspec spec/models  82.52s user 22.83s system 90% cpu 1:56.67 total
```

hm, rather the same, actually. this does ding my theory a bit. There was 1576 users created for this chunk of tests, btw.

seems maybe the same.

Profiled the whole test suite, took forever, trying to play with, and I'm gonna focus on model tests for a time

```
TAG_PROF=type TAG_PROF_FORMAT=html TAG_PROF_EVENT=sql.active_record,sidekiq.inline bin/rspec spec/models
```

something is running slow as hell, but my macbook fan has been pegged for a while, maybe i'll give a restart and try again.

# Thursday, July 11, 2024

bleh

```
TAG_PROF=type TAG_PROF_FORMAT=html TAG_PROF_EVENT=sql.active_record,factory.create bin/rspec spec/features/admin/accounts_spec.rb
```

generates a shit report.

```
TEST_STACK_PROF=1 bin/rspec spec/features/admin/accounts_spec.rb
```

I'm still convinced that devise/bcrypt is responsible for a lot of time being consumed, or at least not convinced it isn't.

as a result of:

`EVENT_PROF="sql.active_record" bundle exec rspec spec`

```
[TEST PROF INFO] EventProf results for sql.active_record

Total time: 01:23.550 of 33:47.296 (4.12%)
Total events: 216403

Top 5 slowest suites (by time):

MoveWorker (./spec/workers/move_worker_spec.rb:5) – 00:03.758 (11300 / 73) of 00:17.556 (21.41%)
ActivityPub::RepliesController (./spec/controllers/activitypub/replies_controller_spec.rb:5) – 00:02.199 (5020 / 36) of 00:09.048 (24.3%)
/api/v1/statuses (./spec/requests/api/v1/statuses_spec.rb:5) – 00:01.964 (1027 / 20) of 01:18.828 (2.49%)
Mastodon::CLI::Maintenance (./spec/lib/mastodon/cli/maintenance_spec.rb:6) – 00:01.936 (2389 / 23) of 00:03.967 (48.81%)
Mastodon::CLI::Accounts (./spec/lib/mastodon/cli/accounts_spec.rb:6) – 00:01.675 (3163 / 102) of 00:11.457 (14.62%)


Finished in 33 minutes 48 seconds (files took 22.43 seconds to load)
```

lets look in detail at some of these:

```
EVENT_PROF="sql.active_record" bundle exec rspec spec/controllers/activitypub/replies_controller_spec.rb

```

Im having trouble capturing factory usage, btw. the normal recommendations didn't acpture it.

I note that devise/bcrypt isn't getting skipped at all.

# Tuesday, September 3, 2024

picking this up first time in a while, but my notes are great so it's easy to do.

Decided to look at the factories more. I ran the `spec/models` directory, looking at the factories, via https://test-prof.evilmartians.io/profilers/factory_prof

` FPROF=1 bundle exec rspec spec/models`

Got this nice output:

[TEST PROF INFO] Time spent in factories: 02:08.891 (73.24% of total time)
[TEST PROF INFO] Factories usage

Total: 2324
Total top-level: 2296
Total time: 02:08.891 (out of 02:56.007)
Total uniq factories: 52

total top-level total time time per call top-level time name

     920         910       26.5414s            0.0288s            26.3044s            account
     635         624       13.7606s            0.0217s            13.4190s             status
     118         118        2.4574s            0.0208s             2.4574s       notification
      91          90        2.4800s            0.0273s             2.4525s               user
      60          60        0.2036s            0.0034s             0.2036s                tag
      39          39       74.3634s            1.9068s            74.3634s   media_attachment
      39          37        0.4662s            0.0120s             0.4433s       custom_emoji
      37          37        1.2884s            0.0348s             1.2884s          favourite
      35          35        0.1203s            0.0034s             0.1203s account_statuses_cleanup_policy
      25          25        0.0782s            0.0031s             0.0782s    software_update
      24          24        0.7614s            0.0317s             0.7614s     follow_request

It continues, but that is a nice starting point.

The total time in factories was 73%, and of that 73%, it looks like 1/4th of it was the account setup time.

Lets see if we can make that go away via the `let it be` hook. I'm also going to re-run the whole test suite now, compare the factory usage in model tests alone (where I expect the time spent in factories might be high) and with the whole suite I expect factory time to be lower.

# Wednesday, September 4, 2024

i'd like to get that total account count down, via `let it be` hooks.

Here's the account spec, before:

```
[TEST PROF INFO] Time spent in factories: 00:09.436 (29.95% of total time)
[TEST PROF INFO] Factories usage

 Total: 193
 Total top-level: 193
 Total time: 00:09.436 (out of 00:31.531)
 Total uniq factories: 9

   total   top-level     total time      time per call      top-level time               name

     158         158        8.6109s            0.0545s             8.6109s            account
      18          18        0.4026s            0.0224s             0.4026s             status
       8           8        0.2198s            0.0275s             0.2198s               user
       2           2        0.0352s            0.0176s             0.0352s         action_log
       2           2        0.0316s            0.0158s             0.0316s          favourite
       2           2        0.0627s            0.0314s             0.0627s              block
       1           1        0.0417s            0.0417s             0.0417s               mute
       1           1        0.0215s            0.0215s             0.0215s canonical_email_block
       1           1        0.0101s            0.0101s             0.0101s             follow
```

Not having luck doing low-touch conversions to `let_it_be`, as the objects are not returned to a correct state, but I did some bad obviously-not-working setup to try to hammer through the error messages.

like:

```ruby
TestProf::BeforeAll.configure do |config|
  config.before(:begin) do
    ActiveRecord::Base.connection_handler.connection_pool_list(:reading).each do |pool|
      pool.connection.begin_transaction(joinable: false)
    end
  end

  config.after(:rollback) do
    ActiveRecord::Base.connection_handler.connection_pool_list(:reading).each do |pool|
      pool.connection.rollback_transaction
    end
  end
end


module ActiveRecordAdapterWithSetup
  class << self
    ACTIVE_RECORD_ADAPTER = TestProf::BeforeAll::Adapters::ActiveRecord

    def begin_transaction
      TestSetup.test_setup

      ACTIVE_RECORD_ADAPTER.begin_transaction
    end

    def rollback_transaction
      ACTIVE_RECORD_ADAPTER.rollback_transaction
    end
  end
end

TestProf::BeforeAll.adapter = ActiveRecordAdapterWithSetup
```

meh. TestProf::BeforeAll::AdapterMissing, Please, provide an adapter for `before_all` through `TestProf::BeforeAll.adapter = MyAdapter`

no clue

# Oct 1

OK, decided to make a minimum mergable PR that is JUST turning off logging, and benchmarking the results, before and after.

My tests seem to be very slow. Currently the process is running the tests at 6gb of memory pressure, and 34% cpu? it seems my tests are taking a lot longer than other people's.

Anyway, I'll reset the code to whatever's on main right now, run tests once or twice, then turn off logs, run them twice more, and maybe go back and forth.

I've modified the gem set heavily as well, currently seeing this printed when I run the tests:

```
21816/5540 |=================== 28 ===================>                                                                                                             |  ETA: 00:11:27
"user 2255"
if you see this, devise/bcrypt didn't get skipped
21827/5540 |=================== 28 ===================>                                                                                                             |  ETA: 00:11:27
"user 2256"
if you see this, devise/bcrypt didn't get skipped
21838/5540 |=================== 28 ===================>                                                                                                             |  ETA: 00:11:26
"user 2257"
if you see this, devise/bcrypt didn't get skipped
21849/5540 |=================== 28 ===================>                                                                                                             |  ETA: 00:11:31
"user 2258"
```

so, I think `gem reset --pristine`, then `git fetch main`, then `git diff`, then do a `git reset --soft`, then discard changes.

I don't want to throw away these notes, for example, but I do want to get rid of all changes I made in the `spec` directory, for example.

```
# update rbenv,
brew upgrade ruby-build
rbenv install 3.3.5
RAILS_ENV='development' NODE_ENV=development bundle install

gem install foreman
RAILS_ENV='development' bundle exec rails db:setup
yarn install
NODE_ENV=development RAILS_ENV=development bundle exec rails webpacker:compile
foreman start

RAILS_ENV='development' bundle exec rails db:setup

NODE_ENV=test RAILS_ENV=test bundle exec rails webpacker:compile

```

debugging the webpacker require stack. fml. I can compile/run in development, I've set `compile:true` in the webpacker settings, I think.

`rails webpacker:compile Cannot find module debug require stack`

jfc got it working. did another `git reset --hard HEAD`, re-installed webpacker, but instead of overwriting conflicts, I rejected any changes where there were conflicts, and then it finally worked.

```
NODE_ENV=test RAILS_ENV=test bundle exec rails webpacker:compile
```

fuck, still errors. I need to see where yarn is installing packages, and make that available to webpacker somehow???? fuuuuuuuuuck.

---

Watching this AMAZING talk that was done SINCE I OPENED THIS PR on THE MASTODON CODE BASE!!!

https://www.youtube.com/watch?v=PvZw0CnZNPc

Vladimir Dementyev, I'd already been trying to channel him, so seeing him bring his mental models to a problem I'd already been noodling on is such a cool opportunity

here we go...

I'll drop time stamps, and am going to try to open a PR containing all his work, which currently doesn't look fully integrated necessarily.

He got his time down by 75%, from 8:30 to 2:30. Big improvements with CI too. wow. I will probably need to take a lot more time to replicate his movement.

## Starting with general profiling

(highly generalizable skill) stack prof and verneer.

getting tests happy again, so did `git remote add upstream mastodon/mastodon` type thing, updated the `main` branch I was looking at locally to the `main` up there. Lots of changes, new ruby version, so I need to update it, etc.

```
brew upgrade ruby-build
rbenv install 3.3.6
bundle install
brew install icu4c # debugging prior command
bundle install
❯ RAILS_ENV=test bin/setup

Running:

```

$ time RAILS_ENV=test b rspec spec/models/
Run options: exclude {:streaming=>true, :search=>true, :js=>true}

Randomized with seed 50162

```
Got:

```

Finished in 1 minute 28.44 seconds (files took 9.81 seconds to load)
1243 examples, 0 failures

RAILs_ENV=test bundle exec rspec spec/models/ 65.37s user 16.02s system 80% cpu 1:41.73 total```

lets see about how to profile this.

Running just the user spec:

```
❯ time RAILs_ENV=test b rspec spec/models/user_spec.rb
Run options: exclude {:streaming=>true, :search=>true, :js=>true}

Randomized with seed 13863
....................................................................

Finished in 11.49 seconds (files took 10.3 seconds to load)
68 examples, 0 failures
```

required test_prof sampling:

```ruby
# gemfile
require "test_prof/recipies/rspec/sample"
```

```
SAMPLE=100 b rspec
Run options: exclude {:streaming=>true, :search=>true, :js=>true}

Randomized with seed 50900
....................................................................................................

Finished in 36.21 seconds (files took 19.62 seconds to load)
100 examples, 0 failures
```

now we can do:

```
❯ SAMPLE=100 b rspec --seed 50900
```

Turn off simple cov running every time:

```diff
diff --git a/spec/rails_helper.rb b/spec/rails_helper.rb

--- a/spec/rails_helper.rb
+++ b/spec/rails_helper.rb
@@ -2,7 +2,7 @@

 ENV['RAILS_ENV'] ||= 'test'

-unless ENV['DISABLE_SIMPLECOV'] == 'true'
+if ENV['COVERAGE'] == 'true'
   require 'simplecov'
```

# Thursday, November 21, 2024

- turn off debugger (saw in vernier & flamegraph)
- turn on webpacker cache_manifest in webpacker.yml
- paperclip
- sidekik
- turn off coverage/simple cov
- turn off logging? didn't seem to make a big difference
-

tagprof profiler

in rails_helper:

`require test_prof/...`?

```
TAG_PROF=type TAG_PROF_FORMAT=html TAG_PROF_EVENT=sql.active_record,factory.create,sidekiq.inline,paperclip,post_process b rspec
```

## January 2025

iirc last time I was struggling to get the tests pristine again, so I could be working off a fairly-close-to-recent copy of the main branch. that broke a bunch of stuff, _including my terminal with this stupid TRX stuff so I got rid of TRX_, finally have tests running again.

anyway, I finally was able to get `bundle install` to work - i hadn't done it since updating my ruby version, which blah blah blah last time I made the PR, this is just all practice anyway. Timing the difference between:

```
$ COVERAGE=true b rspec spec/models/account/field_spec.rb
Run options: exclude {:streaming=>true, :search=>true, :js=>true}

Randomized with seed 41434
.................

Finished in 0.20584 seconds (files took 9.65 seconds to load)
17 examples, 0 failures

Randomized with seed 41434

THESE LINES TOOK A LONG TIME TO GET PRINTED TO THE TERMINAL
Coverage report generated for RSpec to /Users/joshthompson/software_projects/mastodon/coverage.
Line Coverage: 4.31% (1774 / 41114)
Branch Coverage: 3.32% (43 / 1294)
```

and the time was 13 seconds.

Without coverage, thus skipping the load and initialization and everything, it took NINE SECONDS!!! for a big gain.

Huge win.

Next, Vladimir talks about the `I18n.load_path` fix bc internationalization was showing up in some profiling output.

I replecated what he did, and fired up a rails console in a test environment, and ran `I18n.load_path.size`, and got the same value he did, almost. 1159. That's more than we need.

this will speed up the boot process.

calling lots of Devise#encrypt, I already tried to stub this value to share across all objects, per my [openstreetmaps PR](https://github.com/openstreetmap/openstreetmap-website/pull/4708)

Eventually I'll figure out how to jump between my branch and master, timing the two, it'll be a big difference I think.

```
TAG_PROF=type TAG_PROF_FORMAT=html TAG_PROF_EVENT=sql.active_record,factory.create,sidekiq.inline,paperclip.post_process bundle exec rspec
```

Had to try a few times to get the command to work (removed spaces, bundle exec instead of b, and play with where I placed this monitor snippet in the `rails_helper.rb` file. I was getting `uninitialized constant paperclip` otherwise)

```ruby
# rails_helper.rb

require 'test-prof'
TestProf::EventProf.monitor(
  Paperclip::Attachment,
  'paperclip.process_file',
  :process_file
)
```

but now it works. super cool. taking its time, wonder how long the full run will take.

If the report is correct, which it looks like it's generating a report (it says `tagprof enabled` as the tests start...), it'll be super worth it, I think.

His machine ran the tests so fast! He said 1.5 minutes on his machine, for the whole test suite? Mine takes many minutes.

"rails profiling story, or how I caught faker" article, he says maybe a fix in the article he wrote about it: https://evilmartians.com/chronicles/rails-profiling-story-or-how-i-caught-faker-trying-to-teach-my-app-australian-slang

Wowowow. references [this gist](https://gist.github.com/palkan/79fc88207dc856532fb777b8204f7131) that maybe could be copied/pasted into the `rails_helper.rb`? I'll try it once my tests finish running, which is... still happening.

bleh. taking so many minutes. cancelled it. Model tests alone took a minute ten seconds.

Now doing the `Sidekiq::Testing.fake!` and `Sidekiq::Testing.inline!` config change, but it looks like someone else possibly already did this.

No, the tags were not added to the codebase, and I'm not yet replicating the failures.

Might skip this bit to come back later... or just got it:

```
❯ EVENT_PROF=sidekiq.inline bundle exec rspec spec/requests
```

shows nice output: `[TEST PROF INFO] EventProf enabled (sidekiq.inline)`

tests run, then it seems like of the total percent, X% was spent in sidekiq.

'git blame spec/rails_helper.rb`, exploring the commits there, seems this work has not been done.

## Jan 16

a bit more work the next day. tests finished, I really wanna see the `RSTAMP` thing work - mass fix tests?

I 'built up' my understanding of how this method works:

```ruby
# spec/rails_helper
  config.around do |example|
    if example.metadata[:inline_jobs] == true
      Sidekiq::Testing.inline!
    else
      Sidekiq::Testing.fake!
    end
    example.run
  end

```

Seeing the failing tests when I don't toggle to `sidekiq::Testing.inline!`. Sorta? It takes 7 minutes overall to run, wild, and now I'm seeing NO sidekiq.inline usage, which doesn't match my expectations. also 40 failures. Confirming some stuff, seeing lots of passing tests and evidence that the sidekiq testing method thing is working. oh thank god.

Here's how I know:

```ruby
config.around do |example|
    if example.metadata[:inline_jobs] == true
      puts example.metadata[:inline_jobs].to_s
      Sidekiq::Testing.inline!
    else
      Sidekiq::Testing.fake!
    end
    example.run
  end
```

and here's some output from the tests. how nice:

```pre
❯ EVENT_PROF=sidekiq.inline bundle exec rspec spec/requests/
Run options: exclude {:streaming=>true, :search=>true, :js=>true}

Randomized with seed 41852
[TEST PROF INFO] EventProf enabled (sidekiq.inline)
...............................................................................................................................true
.true
...................................................................................................................................................................true
.......................................................................................................................................................................................................................................................................................................................................................................................................true
..............................true
....true
......true
.....true
...true
..........................................................................................................true
.true
.true
.true
................................................................true
.true
..................................................true
.true
.true
```

and sorta tracking how much of the time is spent in `sidekiq.inline` method. It's not been quite as stark as I'd hoped but we'll see. My machine also seems slow as heck.

test prof output:

```
[TEST PROF INFO] EventProf results for sidekiq.inline

Total time: 00:43.509 of 07:07.897 (10.17%)
Total events: 904
```

```
RSTAMP=sidekiq:inline bundle exec rspec spec/requests
```

we'll see if it does anything.
