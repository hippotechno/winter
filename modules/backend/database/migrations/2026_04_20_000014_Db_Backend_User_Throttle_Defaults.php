<?php

use Winter\Storm\Database\Updates\Migration;

class DbBackendUserThrottleDefaults extends Migration
{
    public function up()
    {
        if (!Schema::hasTable('backend_user_throttle')) {
            return;
        }

        DB::statement('ALTER TABLE backend_user_throttle ALTER COLUMN attempts SET DEFAULT 0');
        DB::statement('ALTER TABLE backend_user_throttle ALTER COLUMN is_suspended SET DEFAULT FALSE');
        DB::statement('ALTER TABLE backend_user_throttle ALTER COLUMN is_banned SET DEFAULT FALSE');
    }

    public function down()
    {
        if (!Schema::hasTable('backend_user_throttle')) {
            return;
        }

        DB::statement('ALTER TABLE backend_user_throttle ALTER COLUMN attempts DROP DEFAULT');
        DB::statement('ALTER TABLE backend_user_throttle ALTER COLUMN is_suspended DROP DEFAULT');
        DB::statement('ALTER TABLE backend_user_throttle ALTER COLUMN is_banned DROP DEFAULT');
    }
}
