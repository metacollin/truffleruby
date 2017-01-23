# Copyright (c) 2016 Oracle and/or its affiliates. All rights reserved. This
# code is released under a tri EPL/GPL/LGPL license. You can use it,
# redistribute it and/or modify it under the terms of the:
#
# Eclipse Public License version 1.0
# GNU General Public License version 2
# GNU Lesser General Public License version 2.1

import sys
import os
import pipes
import shutil
import tarfile
import glob
from os.path import join, exists, isdir

import mx
import mx_unittest

TimeStampFile = mx.TimeStampFile

_suite = mx.suite('jruby')

rubyDists = [
    'RUBY',
    'RUBY-TEST'
]

def deploy_binary_if_truffle_head(args):
    """If the active branch is 'truffle-head', deploy binaries for the primary suite to remote maven repository."""
    primary_branch = 'truffle-head'
    active_branch = mx.VC.get_vc(_suite.dir).active_branch(_suite.dir)
    if active_branch == primary_branch:
        return mx.command_function('deploy-binary')(args)
    else:
        mx.log('The active branch is "%s". Binaries are deployed only if the active branch is "%s".' % (active_branch, primary_branch))
        return 0

# Project and BuildTask classes

class ArchiveProject(mx.ArchivableProject):
    def __init__(self, suite, name, deps, workingSets, theLicense, **args):
        mx.ArchivableProject.__init__(self, suite, name, deps, workingSets, theLicense)
        assert 'prefix' in args
        assert 'outputDir' in args

    def output_dir(self):
        return join(self.dir, self.outputDir)

    def archive_prefix(self):
        return self.prefix

    def getResults(self):
        return mx.ArchivableProject.walk(self.output_dir())

class TruffleRubyDocsProject(ArchiveProject):
    doc_files = (glob.glob(join(_suite.dir, 'doc', 'legal', '*')) +
        glob.glob(join(_suite.dir, 'doc', 'user', '*')) +
        glob.glob(join(_suite.dir, '*.md')))

    def getResults(self):
        return [join(_suite.dir, f) for f in self.doc_files]

# Commands

def extractArguments(cli_args):
    vmArgs = []
    rubyArgs = []
    classpath = []
    print_command = False

    jruby_opts = os.environ.get('JRUBY_OPTS')
    if jruby_opts:
        jruby_opts = jruby_opts.split(' ')

    for args in [jruby_opts, cli_args]:
        while args:
            arg = args.pop(0)
            if arg.startswith('-J') or arg.startswith('-J:'):
                if arg.startswith('-J-'):
                    arg = arg[2:]
                elif arg.startswith('-J:'):
                    arg = '-' + arg[3:]
                if arg == '-cmd':
                    print_command = True
                elif arg == '-cp' or arg == '-classpath':
                    cp = args.pop(0)
                    classpath.append(cp)
                else:
                    vmArgs.append(arg)
            elif arg == '--':
                rubyArgs.append(arg)
                rubyArgs.extend(args)
                break
            elif arg[0] == '-':
                rubyArgs.append(arg)
            else:
                rubyArgs.append(arg)
                rubyArgs.extend(args)
                break
    return vmArgs, rubyArgs, classpath, print_command

def setup_ruby_home():
    rubyZip = mx.distribution('RUBY-ZIP').path
    assert exists(rubyZip)
    extractPath = join(_suite.dir, 'mxbuild', 'ruby-zip-extracted')
    if TimeStampFile(extractPath).isOlderThan(rubyZip):
        if exists(extractPath):
            shutil.rmtree(extractPath)
        with tarfile.open(rubyZip, 'r:') as tf:
            tf.extractall(extractPath)
    return extractPath

# Print to stderr, mx.log() outputs to stdout
def log(msg):
    print >> sys.stderr, msg

# This launcher runs similarly to GraalVM,
# with a home only containing files extracted from RUBY-ZIP.
def ruby_command(args):
    """runs Ruby"""
    java_home = os.getenv('JAVA_HOME', '/usr')
    java = os.getenv('JAVACMD', java_home + '/bin/java')
    argv0 = java

    vmArgs, rubyArgs, user_classpath, print_command = extractArguments(args)
    classpath = mx.classpath(['TRUFFLE_API', 'RUBY']).split(':')
    truffle_api, classpath = classpath[0], classpath[1:]
    assert os.path.basename(truffle_api) == "truffle-api.jar"
    # Give precedence to graal classpath and VM options
    classpath = user_classpath + classpath
    vmArgs = vmArgs + [
        # '-Xss2048k',
        '-Xbootclasspath/a:' + truffle_api,
        '-cp', ':'.join(classpath),
        'org.truffleruby.Main'
    ]
    ruby_home = setup_ruby_home()
    rubyArgs = [
        '-Xhome=' + ruby_home,
        '-Xlauncher=' + join(_suite.dir, 'bin', 'truffleruby')
    ] + rubyArgs
    allArgs = vmArgs + rubyArgs

    if print_command:
        if mx.get_opts().verbose:
            log('Environment variables:')
            env = os.environ
            for key in sorted(env.keys()):
                log(key + '=' + env[key])
        log(java + ' ' + ' '.join(map(pipes.quote, allArgs)))
    return os.execv(java, [argv0] + allArgs)

def ruby_tck(args):
    mx_unittest.unittest(['--verbose', '--suite', 'jruby'])

mx.update_commands(_suite, {
    'ruby' : [ruby_command, '[ruby args|@VM options]'],
    'rubytck': [ruby_tck, ''],
    'deploy-binary-if-truffle-head': [deploy_binary_if_truffle_head, ''],
})
