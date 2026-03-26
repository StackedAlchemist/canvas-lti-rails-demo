web: bundle exec rails server -p $PORT -e $RAILS_ENV
worker: bundle exec sidekiq -c 5 -q grades,3 -q default,1
