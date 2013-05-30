## Development Setup

    git clone mroth/emojitrack
    cd emojitrack
    git submodule init
    git submodule update
    bundle install --without=production

## Production setup

    heroku create --stack cedar --addons redistogo:nano memcachier
