mergeNetBSDSourceDir() {
  # merge together all extra paths
  # there should be a better way to do this
  chmod -R u+w $BSDSRCDIR
  for path in $extraPaths; do
    rsync -Er --chmod u+w $path/ $BSDSRCDIR/
  done
}

postUnpackHooks+=(mergeNetBSDSourceDir)
