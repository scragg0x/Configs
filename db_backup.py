#!/usr/bin/env python

"""
This file does some basic and specific backing up of MySQL tables
and sending them to Amazon S3.  This file is used by FFXIAH.com.
"""

import subprocess
from datetime import date

import MySQLdb
import re

mysql_user = ''
mysql_password = ""
database = ''
destination = ""
ignore_table_file = ""
gzip = True
stop_slave_thread = True
s3put = True
s3_key = ""
s3_secret = ""
s3_bucket = ""
s3_prefix = ""
latest_sales_table_file = ''
cmds = []

f = open(latest_sales_table_file, 'w+')
saved_latest_sales = f.read()

conn = MySQLdb.connect('localhost', mysql_user, mysql_password)
c = conn.cursor()

c.execute("SHOW TABLES FROM ah LIKE 'ah_sales_%'")
rows = c.fetchall()

# Get the latest sales table
latest_year = latest_month = None

for row in rows:
    if not row[0]:
        continue
    m = re.match(r"ah_sales_(\d+)_(\d+)", row[0])
    if not m:
       continue
    if not latest_year or latest_year < m.group(2) or (latest_year == m.group(2) and latest_month < m.group(1)):
        latest_year = m.group(2)
        latest_month = m.group(1)

latest_sales_table = "ah_sales_%s_%s" % (latest_month, latest_year)

latest_changed = False
if saved_latest_sales != latest_sales_table:
    # We will save both files
    latest_changed = True

if stop_slave_thread:
    stop_slave_cmd = "mysql -u %s -p%s -e 'STOP SLAVE SQL_THREAD;'" % (mysql_user, mysql_password)
    start_slave_cmd = "mysql -u %s -p%s -e 'START SLAVE SQL_THREAD;'" % (mysql_user, mysql_password)
    cmds.append(stop_slave_cmd)

cmd = "mysqldump -u %s -p%s " % (mysql_user, mysql_password)

sales_cmd = cmd + database + " " + latest_sales_table
sales_cmd2 = cmd + database + " " + saved_latest_sales

if ignore_table_file:
    with open(ignore_table_file) as f:
        lines = f.read().splitlines()
    for line in lines:
        cmd += "--ignore-table=" + database + "." + line + " "

cmd = cmd.rstrip() + " " + database

today = date.today();

if gzip:
    filename = "%s%s.%s.sql.gz" % (destination, database, today.isoformat())
    cmd += " | gzip > %s" % filename
    sales_cmd += " | gzip > %s.sql.gz" % latest_sales_table
    sales_cmd2 += " | gzip > %s.sql.gz" % saved_latest_sales

else:
    filename = " %s%s.sql" % (destination, database)
    cmd += " > %s" % filename
    sales_cmd += " > %s.sql" % latest_sales_table
    sales_cmd2 += " > %s.sql" % saved_latest_sales

cmds.append(cmd)
cmds.append(sales_cmd)

if latest_changed and saved_latest_sales:
    cmds.append(sales_cmd2)

if stop_slave_thread:
    cmds.append(start_slave_cmd)

if s3put:
    s3cmd = "s3put -a %s -s %s -b %s -p %s -c 100 %s" % (s3_key, s3_secret, s3_bucket, s3_prefix, destination)
    cmds.append(s3cmd)
    cmds.append("rm %s*" % destination)
    # Del oldest backup
    cmds.append("s3cmd ls s3://ffxiah/backup/* | grep ah.20* | awk '{print $4}' | head -n 1 | xargs s3cmd del")

for c in cmds:
    print c
    subprocess.call(c, shell=True)

f = open(latest_sales_table_file, 'w+')
f.write(latest_sales_table)
