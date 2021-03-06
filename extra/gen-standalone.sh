#!/bin/bash

(
cat <<END
#!/usr/bin/env ruby
#
# Copyright (c) 2014 William C. Benton and Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

$(for file in ../lib/*.rb ../bin/leitmotif ; do 
    grep -v SKIP_FOR_STANDALONE $file | grep -v \^\#; 
  done)

END
) > standalone/leitmotif 

chmod 755 standalone/leitmotif