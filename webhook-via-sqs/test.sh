github_user="yakireliyahu1987"
github_password="87Yakir87"
github_team="yakireliyahu1987"
github_repo="test-pipeline"
github_secret="m33VNtYL&U5!hn"
read -p "Enter OTP: " OTP
curl -XPOST -H "Accept: application/vnd.github.v3+json" -H "Content-Type: application/json" -H "X-GitHub-OTP: $OTP" -u $github_user:$github_password \
https://api.github.com/repos/$github_team/$github_repo/hooks -d '{
  "name": "web",
  "active": true,
  "events": [
    "push"
  ],
  "config": {
    "url": "https://example.com/",
    "content_type": "json",
    "secret": "'$github_secret'"
  }
}'
