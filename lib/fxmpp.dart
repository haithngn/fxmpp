library fxmpp;

export 'package:xml/xml.dart';
export 'src/fxmpp_platform_interface.dart';
export 'src/fxmpp_method_channel.dart';
export 'src/core/xmpp_connection_config.dart';
export 'src/core/xmpp_connection_state.dart';
export 'src/core/message_type.dart';
export 'src/core/presence_type.dart';
export 'src/core/iq_type.dart';
export 'src/fxmpp.dart';

// MUC (Multi-User Chat) exports
export 'src/muc_manager.dart';
export 'src/core/muc_room.dart';
export 'src/core/muc_participant.dart';
export 'src/core/muc_role.dart';
export 'src/core/muc_affiliation.dart';

// XEP Stanza Builder Methods
export 'src/extensions/xep-0012.dart';
export 'src/extensions/xep-0085.dart';
export 'src/extensions/xep-0184.dart';
export 'src/extensions/xep-0313.dart';
