<?php namespace Backend\FormWidgets;

use Backend\Classes\FormWidgetBase;
use BackendAuth;

/**
 * User/group permission editor
 * This widget is used by the system internally on the System / Administrators pages.
 *
 * Available Modes:
 * - radio: Default mode, used by user-level permissions.
 *   Provides three-state control over each available permission. States are
 *      -1: Explicitly deny the permission
 *      0: Inherit the permission's value from a parent source (User inherits from Role)
 *      1: Explicitly grant the permission
 * - checkbox: Used to define permissions for roles. Intended to define a base of what permissions are available
 *   Provides two state control over each available permission. States are
 *      1: Explicitly allow the permission
 *      null: If the checkbox is not ticked, the permission will not be sent to the server and will not be stored.
 *      This is interpreted as the permission not being present and thus not allowed
 * - switch: Used to define overriding permissions in a simpler UX than the radio.
 *   Provides two state control over each available permission. States are
 *      1: Explicitly allow the permission
 *      -1: Explicitly deny the permission
 *
 * Available permissions can be defined in the form of an array of permission codes to allow:
 * NOTE: Users are still not allowed to modify permissions that they themselves do not have access to
 *     availablePermissions: ['some.author.permission', 'some.other.permission', 'etc.some.system.permission']
 *
 * @package winter\wn-backend-module
 * @author Alexey Bobkov, Samuel Georges
 */
class PermissionEditor extends FormWidgetBase
{
    protected $user;

    /**
     * @var string Mode to display the permission editor with. Available options: radio, checkbox, switch
     */
    public $mode = 'radio';

    /**
     * @var array Permission codes to allow to be interacted with through this widget
     */
    public $availablePermissions;

    /**
     * @inheritDoc
     */
    public function init()
    {
        $this->fillFromConfig([
            'mode',
            'availablePermissions',
        ]);

        $this->user = BackendAuth::getUser();
    }

    /**
     * @inheritDoc
     */
    public function render()
    {
        $this->prepareVars();
        return $this->makePartial('permissioneditor');
    }

    /**
     * Prepares the list data
     */
    public function prepareVars()
    {
        if ($this->formField->disabled) {
            $this->previewMode = true;
        }

        $permissionsData = $this->formField->getValueFromData($this->model);
        if (!is_array($permissionsData)) {
            $permissionsData = [];
        }

        $allPermissions = $this->getFilteredPermissions();
        $pluginOptions = $this->getPluginOptions($allPermissions);
        $selectedPlugin = $this->getSelectedPlugin($pluginOptions);
        $pluginPermissions = $this->filterPermissionsByPlugin($allPermissions, $selectedPlugin);

        $this->vars['mode'] = $this->mode;
        $this->vars['permissions'] = $pluginPermissions;
        $this->vars['baseFieldName'] = $this->getFieldName();
        $this->vars['permissionsData'] = $permissionsData;
        $this->vars['field'] = $this->formField;
        $this->vars['pluginOptions'] = $pluginOptions;
        $this->vars['selectedPlugin'] = $selectedPlugin;
        $this->vars['pluginPermissionCodes'] = $this->listPermissionCodes($pluginPermissions);
    }

    /**
     * @inheritDoc
     */
    public function getSaveValue($value)
    {
        return $this->processSaveValue($value, !$this->user->isSuperUser());
    }

    /**
     * @inheritDoc
     */
    protected function loadAssets()
    {
        $this->addCss('css/permissioneditor.css', 'core');
        $this->addJs('js/permissioneditor.js', 'core');
    }

    /**
     * Returns a safely parsed set of permissions, ensuring the user cannot elevate
     * their own permissions or permissions of another user above their own.
     *
     * @param string $value
     * @return array
     */
    protected function getSaveValueSecure($value)
    {
        return $this->processSaveValue($value, true);
    }

    /**
     * Returns a safely parsed set of permissions, ensuring the user cannot elevate
     * their own permissions or permissions of another user above their own.
     *
     * @param string $value
     * @param bool $enforceAccess
     * @return array
     */
    protected function processSaveValue($value, bool $enforceAccess = true)
    {
        $pluginCode = null;
        if (is_array($value) && array_key_exists('_plugin', $value)) {
            $pluginCode = $value['_plugin'];
            unset($value['_plugin']);
        }

        $newPermissions = is_array($value) ? array_map('intval', $value) : [];
        $pluginCode = $pluginCode ?? post($this->getFieldName() . '_plugin');

        $existingPermissions = $this->model->permissions;
        if (!is_array($existingPermissions)) {
            $existingPermissions = [];
        }

        if ($pluginCode) {
            $allowedForPlugin = $this->listPermissionCodes(
                $this->getFilteredPermissions($pluginCode)
            );

            foreach ($allowedForPlugin as $permissionCode) {
                unset($existingPermissions[$permissionCode]);
            }
        }

        if (!empty($newPermissions)) {
            $allowedPermissions = $enforceAccess
                ? array_map(function ($permissionObject) {
                    return $permissionObject->code;
                }, array_flatten($this->getFilteredPermissions($pluginCode ?: null)))
                : array_keys($newPermissions);

            foreach ($newPermissions as $permission => $code) {
                if (in_array($permission, $allowedPermissions)) {
                    $existingPermissions[$permission] = $code;
                }
            }
        }

        return $existingPermissions;
    }

    /**
     * Returns the available permissions; removing those that the logged-in user does not have access to
     *
     * @return array The permissions that the logged-in user does have access to ['permission-tab' => $arrayOfAllowedPermissionObjects]
     */
    protected function getFilteredPermissions($onlyPlugin = null)
    {
        $permissions = BackendAuth::listTabbedPermissions();

        foreach ($permissions as $tab => $permissionsArray) {
            foreach ($permissionsArray as $index => $permission) {
                if (!$this->user->hasAccess($permission->code) ||
                    (
                        is_array($this->availablePermissions) &&
                        !in_array($permission->code, $this->availablePermissions)
                    ) ||
                    (
                        $onlyPlugin &&
                        $this->extractPluginCode($permission->code) !== $onlyPlugin
                    )) {
                    unset($permissionsArray[$index]);
                }
            }

            if (empty($permissionsArray)) {
                unset($permissions[$tab]);
            }
            else {
                $permissions[$tab] = array_values($permissionsArray);
            }
        }

        return $permissions;
    }

    /**
     * AJAX handler: returns permission table for a single plugin.
     */
    public function onLoadPermissions()
    {
        $permissionsData = $this->formField->getValueFromData($this->model);
        if (!is_array($permissionsData)) {
            $permissionsData = [];
        }

        $allPermissions = $this->getFilteredPermissions();
        $pluginOptions = $this->getPluginOptions($allPermissions);
        $selectedPlugin = post('plugin');
        if (!$selectedPlugin || !array_key_exists($selectedPlugin, $pluginOptions)) {
            $selectedPlugin = $this->getSelectedPlugin($pluginOptions);
        }

        $pluginPermissions = $this->filterPermissionsByPlugin($allPermissions, $selectedPlugin);

        $this->vars['mode'] = $this->mode;
        $this->vars['permissions'] = $pluginPermissions;
        $this->vars['baseFieldName'] = $this->getFieldName();
        $this->vars['permissionsData'] = $permissionsData;
        $this->vars['field'] = $this->formField;
        $this->vars['selectedPlugin'] = $selectedPlugin;
        $this->vars['pluginPermissionCodes'] = $this->listPermissionCodes($pluginPermissions);

        return [
            'result' => $this->makePartial('permissioneditor_table'),
        ];
    }

    /**
     * Builds list of plugin options from available permissions.
     */
    protected function getPluginOptions(array $permissions): array
    {
        $plugins = [];

        foreach ($permissions as $tabPermissions) {
            foreach ($tabPermissions as $permission) {
                $pluginCode = $this->extractPluginCode($permission->code);
                if (!array_key_exists($pluginCode, $plugins)) {
                    $plugins[$pluginCode] = $this->formatPluginLabel($pluginCode);
                }
            }
        }

        ksort($plugins);

        return $plugins;
    }

    /**
     * Returns the selected plugin code.
     */
    protected function getSelectedPlugin(array $pluginOptions): ?string
    {
        $requested = post($this->getFieldName() . '_plugin');
        if ($requested && array_key_exists($requested, $pluginOptions)) {
            return $requested;
        }

        return count($pluginOptions) ? array_key_first($pluginOptions) : null;
    }

    /**
     * Filters permissions array down to a single plugin.
     */
    protected function filterPermissionsByPlugin(array $permissions, ?string $pluginCode): array
    {
        if (!$pluginCode) {
            return [];
        }

        $filtered = [];
        foreach ($permissions as $tab => $permissionSet) {
            foreach ($permissionSet as $permission) {
                if ($this->extractPluginCode($permission->code) !== $pluginCode) {
                    continue;
                }
                $filtered[$tab][] = $permission;
            }
        }

        return $filtered;
    }

    /**
     * Extracts plugin code from permission code.
     */
    protected function extractPluginCode(string $permissionCode): string
    {
        $parts = explode('.', $permissionCode);

        if (count($parts) >= 2) {
            return $parts[0] . '.' . $parts[1];
        }

        return 'other';
    }

    /**
     * Formats plugin code for dropdown display.
     */
    protected function formatPluginLabel(string $pluginCode): string
    {
        $parts = explode('.', $pluginCode);
        $parts = array_map(function ($part) {
            return ucwords(str_replace('_', ' ', $part));
        }, $parts);

        return implode(' / ', $parts);
    }

    /**
     * Returns a flat list of permission codes from a permission array.
     */
    protected function listPermissionCodes(array $permissions): array
    {
        $codes = [];
        foreach ($permissions as $tabPermissions) {
            foreach ($tabPermissions as $permission) {
                $codes[] = $permission->code;
            }
        }

        return $codes;
    }
}
