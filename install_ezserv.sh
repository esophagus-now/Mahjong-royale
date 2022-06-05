#!/bin/bash

lua_version=$(lua -e "print(_VERSION:match('%S*$'))")
boost_dir=$(cpp -xc++ -v < /dev/null 2>&1 | grep -e "-boost-" | grep -v -i "gcc" | grep -v "duplicate" | sed 's/ //g')
boost_dir=${boost_dir%include}

luarocks --tree ./rocks --lua-version $lua_version install ezserv LIBBOOST_DIR=${boost_dir}
