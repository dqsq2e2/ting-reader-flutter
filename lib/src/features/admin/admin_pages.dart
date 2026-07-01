import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/external_links.dart';
import '../../core/utils/locale.dart';
import '../../shared/app_scope.dart';
import '../../shared/cards/book_card.dart';
import '../../shared/common/common_widgets.dart';
import '../../shared/dialogs/dialog_label.dart';

part 'libraries/admin_libraries_page.dart';
part 'libraries/library_folder_picker.dart';
part 'libraries/library_scraper_config.dart';
part 'libraries/library_editor_dialog.dart';
part 'logs_page.dart';
part 'plugins_page.dart';
