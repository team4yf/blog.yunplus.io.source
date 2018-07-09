#! /bin/sh

cd source
git add --all . 
git commit -m 'stash:source'
git pull
if [ $1 = 'pull' ]; then
  cd ..
  npm run generate
fi
if [ $1 = 'push' ]; then
  git push
  cd ..
fi
echo "ok"
exit
