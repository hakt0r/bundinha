#! /bin/bash

### BEGIN INIT INFO
# Provides:          cinv
# Required-Start:    $local_fs $network
# Required-Stop:     $local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: cinv
# Description:       Run cinv backend
### END INIT INFO

# Carry out specific functions when asked to by the system
case "$1" in
  start)
    echo "Starting cinv backend..."
    RUN_CINV
    ;;
  stop)
    echo "Stopping cinv backend..."
    STOP_CINV
    ;;
  *)
    echo "Usage: /etc/init.d/cinv {start|stop}"
    exit 1
    ;;
esac

exit 0
