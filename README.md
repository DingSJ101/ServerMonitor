# ServerMonitor
use a shell script to capture the server status ,e.g. cpu/memory.. and send the status to a url

# Usage
rename config_template.json  as config.json

write your own configuration there
## send localhost machine status
```bash
bash ServerMonitor.sh
```


### set cron task to run script periodically
```crontab
# run every 10 minutes
*/10 * * * * bash absolute_path/ServerMonitor.sh >> absolute_path/log.txt
```