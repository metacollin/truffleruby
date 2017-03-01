#!/usr/bin/env ruby
# Copyright (c) 2016 Oracle and/or its affiliates. All rights reserved.
# This code is released under a tri EPL/GPL/LGPL license. You can use it,
# redistribute it and/or modify it under the terms of the:
#
# Eclipse Public License version 1.0
# GNU General Public License version 2
# GNU Lesser General Public License version 2.1

require 'json'

result = JSON.parse(File.read(ARGV[0]))
wait = ARGV[1] == '--wait'

failures = []

known_failures = [
  ["server", "graal-enterprise-no-om", "jruby", "truffle", "asciidoctor", "asciidoctor:load-file"],
  ["server", "graal-enterprise-no-om", "jruby", "truffle", "server", "tcp-server"],
  ["server", "graal-enterprise", "jruby", "truffle", "server", "tcp-server"],
  ["server", "graal-enterprise", "jruby", "truffle", "asciidoctor", "asciidoctor:load-file"],
  ["server", "graal-core", "jruby", "truffle", "server", "tcp-server"],
  ["server", "graal-core", "jruby", "truffle", "asciidoctor", "asciidoctor:load-file"],
  ["server", "graal-vm", "jruby", "truffle", "asciidoctor", "asciidoctor:load-file"],
  ["server", "graal-vm", "jruby", "truffle", "server", "tcp-server"],
  ["server", "graal-vm-snap", "jruby", "truffle", "server", "tcp-server"],
  ["server", "graal-vm-snap", "jruby", "truffle", "asciidoctor", "asciidoctor:load-file"],
  ["server", "graal-vm", "jruby", "truffle", "chunky", "chunky-decode-png-image-pass"],
  ["server", "graal-vm-snap", "jruby", "truffle", "chunky", "chunky-decode-png-image-pass"],
  ["server", "graal-core", "jruby", "truffle", "optcarrot", "optcarrot"],
  ["server", "graal-core", "jruby", "truffle", "micro", "micro/core/file.rb:core-read-gigabyte"],
  ["server", "graal-core", "jruby", "truffle", "asciidoctor", "asciidoctor:load-string"],
  ["server", "graal-core", "jruby", "truffle", "chunky", "chunky-operations-compose"],
  ["server", "svm", "jruby", "truffle", "asciidoctor", "asciidoctor:file-lines"],
  ["server", "svm", "jruby", "truffle", "asciidoctor", "asciidoctor:load-string"],
  ["server", "svm", "jruby", "truffle", "asciidoctor", "asciidoctor:load-file"],
  ["server", "svm", "jruby", "truffle", "classic", "binary-trees"],
  ["server", "svm", "jruby", "truffle", "psd", "psd-compose-color-burn"],
  ["server", "svm", "jruby", "truffle", "psd", "psd-compose-color-dodge"],
  ["server", "svm", "jruby", "truffle", "psd", "psd-compose-exclusion"],
  ["server", "svm", "jruby", "truffle", "psd", "psd-compose-hard-light"],
  ["server", "svm", "jruby", "truffle", "psd", "psd-compose-lighten"],
  ["server", "svm", "jruby", "truffle", "psd", "psd-compose-linear-burn"],
  ["server", "svm", "jruby", "truffle", "psd", "psd-compose-multiply"],
  ["server", "svm", "jruby", "truffle", "psd", "psd-compose-normal"],
  ["server", "svm", "jruby", "truffle", "psd", "psd-compose-overlay"],
  ["server", "svm", "jruby", "truffle", "psd", "psd-compose-screen"],
  ["server", "svm", "jruby", "truffle", "psd", "psd-compose-vivid-light"],
  ["server", "svm", "jruby", "truffle", "psd", "psd-renderer-blender-compose"],
  ["server", "svm", "jruby", "truffle", "savina", "savina-radix-sort"],
  ["server", "svm", "jruby", "truffle", "server", "tcp-server"],
  ["server", "svm", "jruby", "truffle", "server", "webrick"]
]

if File.exist?('failures')
  failures = File.read('failures').split("\n").map { |failure| eval(failure) }
else
  failures = []
end

(result['queries'] || []).any? do |q|
  if q['error'] == 'failed'
    failures.push [q['host-vm'], q['host-vm-config'], q['guest-vm'], q['guest-vm-config'], q['bench-suite'], q['benchmark']]
  end
end

known_failures.each do |known_failure|
  if failures.delete(known_failure)
    STDERR.puts "#{known_failure.inspect} failed, but we know about that"
  end
end

if wait
  if !failures.empty?
    STDERR.puts 'waiting to return failure...'
    File.write('failures', failures.map(&:inspect).join("\n"))
  end
else
  if !failures.empty? || File.exist?('failures')
    STDERR.puts 'these failed:'
    failures.each do |failure|
      STDERR.puts failure.inspect
    end
    exit 1
  end
end
