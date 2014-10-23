# About Spacewalk

  * http://github.com/kkaempf/ruby-spacewalk
  * http://spacewalk.redhat.com/
  * http://www.suse.com/products/suse-manager

## DESCRIPTION

Spacewalk is a pure-Ruby implementation of the Spacewalk client
protocol stack.

## COMMANDS

The `bin` subdir contains a couple of commands to simulate a client
talking to the Spacewalk server.

#### Command options

All commands have the following options in common

  * `--server <spacewalk-url>` to specify the full url of the spacewalk server
    * Example: `--server http://spacewalk.opensuse.org`

### Registration

The `register_remote` fakes a registration of a client system and
stores the `system_id` as a file with the system name.

#### Synopsis

  `register_remote <options> <client-system-name>`

  Possible `<options>`:
  * `--server <spacewalk-url>` - required, specifies the spacewalk server
  * `--key <activation-key>` - requires, specifies the activation key
  * `--packages` - optional, upload locally installed packages
  * `--description <text>` - optional, a text line to identify the system
  * `--arch <arch>` - optional, to simulate different architectures

#### Registration example

  `ruby register_remote.rb --server https://spacewalk.opensuse.org --key 1-default --packages --description "Fake registration" --arch x86_64 my.system.com`

### Actions

The `actions` command pulls pending actions from the server and
outputs matching CFEngine promises. Actions are then marked as
'successful'.

If `--future <hours>` is given, actions are not marked and will stay
pending in the server.

#### Synopsis

  `actions <options> <client-system-name>`

  Possible `<options>`:
  * `--server <spacewalk-url>` - required, specifies the spacewalk server
  * `--future <hours>` - optional, returns future actions

#### Actions example

  `ruby actions.rb --server https://spacewalk.opensuse.org --future 1 my.system.com`

### Action results

`submit` is a helper tool to submit action results back to the server.
This can be used for actions marked as 'in progress', waiting for the
client to submit a final result.

#### Synopsis

  `submit <options> <client-system-name>`

  Possible `<options>`:
  * `--server <spacewalk-url>` - required, specifies the spacewalk server
  * `--action <action_id>` - required, the id of the action
  * `--message <text>` - optional, text information about the result
  * `--result <exit-code>` - optional, exit code of a command

### Action results examples

  `ruby submit.rb --server https://spacewalk.opensuse.org --action 6434 --message "Leider kaputt" --result "0" my.system.com`

## REQUIREMENTS

  * Ruby

## INSTALL

  * sudo gem install spacewalk

## LICENSE:

(The Ruby License)

Copyright (c) 2011-2014 SUSE Linux Products GmbH

See http://www.ruby-lang.org/en/LICENSE.txt for the full text
