<div
    class="uk-margin-small permission-table"
    data-permission-table
    data-permission-mode="<?= $this->mode ?>">
    <input type="hidden" name="<?= e($baseFieldName) ?>[_plugin]" value="<?= e($selectedPlugin) ?>">

    <?php if (empty($permissions)): ?>
        <div class="uk-alert uk-alert-primary">Không có quyền cho plugin này.</div>
    <?php else: ?>
        <div class="uk-margin-small">
            <button type="button" class="uk-button uk-button-primary" data-global-toggle>
                Toggle
            </button>
        </div>
        <ul class="uk-accordion uk-accordion-outline" uk-accordion="multiple: true">
            <?php
            $firstTab = true;
            $globalIndex = 0;
            $checkboxMode = !($this->mode === 'radio');
            ?>
            <?php foreach ($permissions as $tab => $tabPermissions): ?>
                <li class="<?= $firstTab ? 'uk-open' : '' ?>">
                    <h3 class="uk-accordion-title"><?= e(trans($tab)) ?></h3>
                    <div class="uk-accordion-content">
                        <div class="perm-tools uk-margin-small uk-flex uk-flex-middle uk-flex-wrap">
                            <div class="uk-flex-1 uk-margin-small-right">
                                <input type="text" class="uk-input permission-search" placeholder="Search permissions..." data-permission-search>
                            </div>

                            <div class="uk-inline uk-margin-small-top@s">
                                <button class="uk-button uk-button-default" type="button">
                                    Toggle theo Action
                                </button>
                                <div uk-dropdown="mode: click">
                                    <ul class="uk-nav uk-dropdown-nav action-toggle-dropdown">
                                        <li><a href="#" data-action="manage" data-action-toggle>Toggle Manage</a></li>
                                        <li><a href="#" data-action="view" data-action-toggle>Toggle View</a></li>
                                        <li><a href="#" data-action="create" data-action-toggle>Toggle Create</a></li>
                                        <li><a href="#" data-action="update" data-action-toggle>Toggle Update</a></li>
                                        <li><a href="#" data-action="delete" data-action-toggle>Toggle Delete</a></li>
                                        <li><a href="#" data-action="import" data-action-toggle>Toggle Import</a></li>
                                        <li><a href="#" data-action="export" data-action-toggle>Toggle Export</a></li>
                                    </ul>
                                </div>
                            </div>
                        </div>

                        <table class="uk-table">
                            <?php
                            $lastIndex = count($tabPermissions) - 1;
                            $prevGroupKey = null;
                            ?>
                            <?php foreach ($tabPermissions as $index => $permission): ?>
                                <?php
                                $globalIndex++;

                                switch ($this->mode) {
                                    case 'radio':
                                        $permissionValue = array_key_exists($permission->code, $permissionsData)
                                            ? $permissionsData[$permission->code]
                                            : 0;
                                        break;
                                    case 'switch':
                                        $isChecked = !((int) @$permissionsData[$permission->code] === -1);
                                        break;
                                    case 'checkbox':
                                    default:
                                        $isChecked = array_key_exists($permission->code, $permissionsData);
                                        break;
                                }

                                $allowId = $this->getId('permission-' . $globalIndex . '-allow');
                                $inheritId = $this->getId('permission-' . $globalIndex . '-inherit');
                                $denyId = $this->getId('permission-' . $globalIndex . '-deny');
                                ?>
                                <?php
                                $parts = explode('.', $permission->code);

                                if (count($parts) >= 3) {
                                    $groupKey = $parts[0] . '.' . $parts[1] . '.' . $parts[2];
                                } else {
                                    $groupKey = 'special';
                                }

                                if ($prevGroupKey !== $groupKey) {
                                ?>
                                    <tr class="permission-group-row" data-perm-group="<?= $groupKey ?>">
                                        <td colspan="4" class="uk-text-bold uk-background-muted">
                                            <?php
                                            $displayName = $groupKey;
                                            if ($groupKey !== 'special') {
                                                $groupParts = explode('.', $groupKey);
                                                $modelName = isset($groupParts[2]) ? $groupParts[2] : $groupKey;
                                                $displayName = ucwords(str_replace('_', ' ', $modelName));
                                            } else {
                                                $displayName = 'Đặc biệt';
                                            }
                                            echo $displayName;
                                            ?>
                                        </td>
                                        <td class="uk-text-right">
                                            <button type="button" class="uk-button uk-button-mini uk-button-primary" data-group-toggle data-group="<?= $groupKey ?>">Toggle</button>
                                        </td>
                                    </tr>
                                <?php
                                }
                                $prevGroupKey = $groupKey;
                                ?>

                                <?php
                                $action = isset($parts[3]) ? $parts[3] : '';
                                ?>
                                <tr
                                    data-perm-item="<?= $permission->code ?>"
                                    data-perm-group="<?= $groupKey ?>"
                                    data-perm-action="<?= $action ?>"
                                    class="<?= $lastIndex == $index ? 'last-section-row' : '' ?>
                                        <?= $checkboxMode ? 'mode-checkbox' : 'mode-radio' ?>
                                        <?= $checkboxMode && !$isChecked ? 'disabled' : '' ?>
                                        <?= !$checkboxMode && $permissionValue == -1 ? 'disabled' : '' ?>"
                                >
                                    <td class="permission-name">
                                        <?= e(trans($permission->label)) ?>
                                        <?php if ($permission->comment): ?>
                                            <div class="text-muted small"><?= e(trans($permission->comment)) ?></div>
                                        <?php endif; ?>
                                    </td>

                                    <?php if ($this->mode === 'radio'): ?>
                                        <td class="permission-value">
                                            <div class="radio custom-radio">
                                                <input
                                                    id="<?= $allowId ?>"
                                                    name="<?= e($baseFieldName) ?>[<?= e($permission->code) ?>]"
                                                    value="1"
                                                    type="radio"
                                                    <?= $permissionValue == 1 ? 'checked="checked"' : '' ?>
                                                    data-radio-color="green">

                                                <label for="<?= $allowId ?>"><span>Allow</span></label>
                                            </div>
                                        </td>
                                        <td class="permission-value">
                                            <div class="radio custom-radio">
                                                <input
                                                    id="<?= $inheritId ?>"
                                                    name="<?= e($baseFieldName) ?>[<?= e($permission->code) ?>]"
                                                    value="0"
                                                    <?= $permissionValue == 0 ? 'checked="checked"' : '' ?>
                                                    type="radio">

                                                <label for="<?= $inheritId ?>"><span>Inherit</span></label>
                                            </div>
                                        </td>
                                        <td class="permission-value">
                                            <div class="radio custom-radio">
                                                <input
                                                    id="<?= $denyId ?>"
                                                    name="<?= e($baseFieldName) ?>[<?= e($permission->code) ?>]"
                                                    value="-1"
                                                    <?= $permissionValue == -1 ? 'checked="checked"' : '' ?>
                                                    type="radio"
                                                    data-radio-color="red">

                                                <label for="<?= $denyId ?>"><span>Deny</span></label>
                                            </div>
                                        </td>
                                        <td></td>
                                    <?php elseif ($this->mode === 'switch'): ?>
                                        <td class="permission-value">
                                            <input
                                                type="hidden"
                                                name="<?= e($baseFieldName) ?>[<?= e($permission->code) ?>]"
                                                value="-1">

                                            <label class="custom-switch">
                                                <input
                                                    id="<?= $allowId ?>"
                                                    name="<?= e($baseFieldName) ?>[<?= e($permission->code) ?>]"
                                                    value="1"
                                                    type="checkbox"
                                                    <?= $isChecked ? 'checked="checked"' : '' ?>>
                                                <span><span><?= e(trans('backend::lang.list.column_switch_true')) ?></span><span><?= e(trans('backend::lang.list.column_switch_false')) ?></span></span>
                                                <a class="slide-button"></a>
                                            </label>
                                        </td>
                                        <td></td>
                                        <td></td>
                                    <?php else: ?>
                                        <td class="permission-value">
                                            <div class="checkbox custom-checkbox">
                                                <input
                                                    id="<?= $allowId ?>"
                                                    name="<?= e($baseFieldName) ?>[<?= e($permission->code) ?>]"
                                                    value="1"
                                                    type="checkbox"
                                                    <?= $isChecked ? 'checked="checked"' : '' ?>>

                                                <label for="<?= $allowId ?>"><span>Allow</span></label>
                                            </div>
                                        </td>
                                        <td></td>
                                        <td></td>
                                    <?php endif; ?>

                                </tr>
                            <?php endforeach ?>
                        </table>
                    </div>
                </li>
                <?php $firstTab = false; ?>
            <?php endforeach ?>
        </ul>
    <?php endif; ?>
</div>
