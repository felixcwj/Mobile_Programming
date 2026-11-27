import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/firebase_accounts.dart';
import '../services/planit_api.dart';
import 'generated/app_localizations.dart';
import 'generated/app_localizations_ko.dart';

final _koreanFallback = AppLocalizationsKo();

AppLocalizations l10n(BuildContext context) =>
    AppLocalizations.of(context) ?? _koreanFallback;

String displayLabel(BuildContext context, String label) {
  final strings = l10n(context);
  return switch (label) {
    "반복되지 않음" => strings.doesNotRepeat,
    "매일" => strings.daily,
    "매주" => strings.weekly,
    "매월" => strings.monthly,
    "매년" => strings.yearly,
    "개인" => strings.personal,
    "대학" => strings.school,
    "업무" => strings.work,
    "약속방" => strings.room,
    "외부 활동" => strings.outdoorActivities,
    "실내 활동" => strings.indoorActivities,
    "둘 다 좋아요" => strings.both,
    "여성" => strings.female,
    "남성" => strings.male,
    "기타" => strings.other,
    "응답하지 않음" => strings.preferNotToSay,
    "잘 모르겠어요" => strings.iMNotSure,
    "전체 약속" => strings.allPlans,
    "취향 진행 중" => strings.collectingPreferences2,
    "확정된 약속" => strings.confirmedPlans,
    "초록" => strings.green,
    "파랑" => strings.blue,
    "보라" => strings.purple,
    "주황" => strings.orange,
    "분홍" => strings.pink,
    "빨강" => strings.red,
    "노랑" => strings.yellow,
    "청록" => strings.teal,
    _ => label,
  };
}

String displayError(BuildContext context, Object error) {
  if (error case PlanitApiException(isServerMessage: true)) {
    return error.message;
  }
  if (error case AccountException(isServerMessage: true)) {
    return error.message;
  }
  final strings = l10n(context);
  final message = switch (error) {
    PlanitApiException() => error.message,
    AccountException() => error.message,
    FormatException() => error.message,
    StateError() => error.message,
    _ => error.toString(),
  };
  final status = RegExp(
    r'^서버 응답이 올바르지 않습니다\. \(HTTP (\d+)\)$',
  ).firstMatch(message);
  if (status != null) return strings.invalidServerResponse(status[1]!);
  return switch (message) {
    "서버 주소가 설정되지 않았습니다. PLANIT_API_BASE_URL을 확인하세요." =>
      strings.theServerAddressIsMissingCheckPlanit,
    "서버 주소 형식이 올바르지 않습니다." => strings.theServerAddressIsInvalid,
    "로그인이 필요합니다." => strings.signInToContinue,
    "인증 토큰을 가져오지 못했습니다." => strings.couldNotRetrieveTheAuthenticationToken,
    "서버 응답이 지연되고 있습니다. 다시 시도해 주세요." => strings.theServerTookTooLongToRespond,
    "서버에 연결할 수 없습니다. 인터넷과 서버 주소를 확인하세요." =>
      strings.couldNotConnectToTheServerCheck,
    "요청을 처리하지 못했습니다." => strings.couldNotCompleteTheRequest,
    "서버 데이터 형식이 올바르지 않습니다." => strings.theServerReturnedDataInAnUnexpected,
    "프로필 사진은 250KB 이하로 선택해 주세요." => strings.chooseAProfilePhotoUpToKb,
    "계정은 생성되었지만 자동 로그인에 실패했습니다. 로그인 화면에서 다시 시도해 주세요." =>
      strings.yourAccountWasCreatedPleaseSignIn,
    "서버에서 계정 이메일을 받지 못했습니다." => strings.theServerDidNotReturnTheAccount,
    "서버와 Firebase 계정 정보가 일치하지 않습니다." =>
      strings.theServerAndFirebaseAccountDetailsDo,
    "로그인하지 못했습니다. 아이디와 비밀번호를 확인해 주세요." =>
      strings.couldNotSignInCheckYourUsername2,
    "다른 사용자의 프로필을 저장할 수 없습니다." => strings.youCanOnlySaveYourOwnProfile,
    "비밀번호가 변경됐습니다. 보안을 위해 다시 로그인해 주세요." =>
      strings.yourPasswordChangedPleaseSignInAgain,
    "방 ID를 받지 못했습니다." => strings.theServerDidNotReturnARoom,
    "지도에서 확인할 수 없는 국내 지역입니다." => strings.thisAreaInSouthKoreaCouldNot,
    "확정된 약속 정보를 확인할 수 없습니다." => strings.couldNotRetrieveTheConfirmedPlan,
    "약속 확정은 방장만 할 수 있습니다." => strings.onlyTheRoomOwnerCanConfirmThe,
    "최신 AI 추천을 먼저 불러와 주세요." => strings.loadTheLatestAiRecommendationsFirst,
    "HTTPS 서버 주소를 입력해 주세요. 내부망 HTTP는 개발용 디버그 앱에서만 지원합니다." =>
      strings.enterAnHttpsServerAddressDebugBuilds,
    "서버 주소를 저장하지 못했습니다." => strings.couldNotSaveTheServerAddress,
    "서버 주소 초기화에 실패했습니다." => strings.couldNotResetTheServerAddress,
    "서버 상태가 정상이 아닙니다." => strings.theServerHealthCheckFailed,
    "서버 연결 후 방에서 나갈 수 있습니다." => strings.connectToTheServerToLeaveThe,
    _ => message,
  };
}

String planDateLabel(
  BuildContext context,
  DateTime date, {
  bool includeYear = true,
  bool weekday = true,
}) {
  final strings = l10n(context);
  if (strings.localeName == 'en') {
    if (!weekday) return DateFormat.yMMMd('en_US').format(date);
    return (includeYear
            ? DateFormat.yMMMEd('en_US')
            : DateFormat.MMMEd('en_US'))
        .format(date);
  }
  final days = [
    strings.monday,
    strings.tuesday,
    strings.wednesday,
    strings.thursday,
    strings.friday,
    strings.saturday,
    strings.sunday,
  ];
  final year = includeYear ? '${date.year}년 ' : '';
  final day = weekday ? ' (${days[date.weekday - 1]})' : '';
  return '$year${date.month}월 ${date.day}일$day';
}

String planMonthLabel(BuildContext context, DateTime date) =>
    l10n(context).localeName == 'ko'
    ? '${date.year}년 ${date.month}월'
    : DateFormat.yMMMM('en_US').format(date);

String planCompactDate(BuildContext context, DateTime date) =>
    l10n(context).localeName == 'ko'
    ? DateFormat('yyyy.MM.dd', 'en_US').format(date)
    : DateFormat.yMMMd('en_US').format(date);
