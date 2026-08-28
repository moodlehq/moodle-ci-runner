#!/usr/bin/env sh

npx zh-adoption auth
npx zh-adoption analyze --interactive false --ignore "**/*.test.*" --repo-name "Moodle"
