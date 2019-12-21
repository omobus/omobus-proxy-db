/* Copyright (c) 2006 - 2019 omobus-proxy-db authors, see the included COPYRIGHT file. */

delete from activity_types;
insert into activity_types(activity_type_id, descr, note, docs_needed, exec_limit, strict, selectable)
    values('0', 'Посещение', 'Плановый визит к клиенту.', 1, 1, 1, 0);
insert into activity_types(activity_type_id, descr, note, docs_needed, exec_limit, strict, selectable, row_no, roles)
    values('1', 'Внеплановое посещение', 'Внеплановый визит к клиенту. Не влияет на выполнение планов по посещениям.', 0, 4, 1, 1, 1, array['merch','mr','ksr','sr']::uids_t);
insert into activity_types(activity_type_id, descr, note, docs_needed, exec_limit, selectable, roles)
    values('2', 'Звонок клиента(-у)', 'Прием документов по телефону. Не влияет на выполнение планов по посещениям.', 0, 255, 1, array['sr','sv']::uids_t);
insert into activity_types(activity_type_id, descr, note, docs_needed, exec_limit, selectable)
    values('3', 'Анализ информации', 'Просмотр отчетов. Не влияет на выполнение планов по посещениям.', 0, 255, 1);
insert into activity_types(activity_type_id, descr, note, docs_needed, exec_limit, strict, selectable, roles, row_no)
    values('4', 'Контрольное посещение', 'Посещение клиента для контроля/аудита результатов работы сотрудников.', 0, 2, 1, 1, array['sv','ise','asm','kam','tme']::uids_t, 0);
insert into activity_types(activity_type_id, descr, note, docs_needed, exec_limit, strict, selectable, roles, joint, row_no)
    values('5', 'Совместное посещение', 'Посещение клиента совместно с подчиненным.', 0, 2, 1, 1, array['sv','ise','asm']::uids_t, 1, 0);
insert into activity_types(activity_type_id, descr, note, docs_needed, exec_limit, strict, selectable, roles, hidden, row_no)
    values('6', 'Повторное посещение', 'Выполнение повторного визита к клиенту из планового маршрута. Не влияет на выполнение планов по посещениям.', 1, 1, 1, 1, array['merch','mr','ksr','sr']::uids_t, 1, 0);
insert into activity_types(activity_type_id, descr, note, docs_needed, exec_limit, strict, selectable, important)
    values('7', 'Срочное посещение', 'Срочный визит в торговую точку для устранения нарушений, выявленных в ходе контрольного посещения (аудита).', 1, 1, 1, 0, 1);
insert into activity_types(activity_type_id, descr, note, docs_needed, exec_limit, strict, selectable, row_no, roles, hidden)
    values('8', 'Свободное посещение', 'Плановый визит к клиенту.', 1, 1, 1, 1, 0, array['merch','mr','ksr','sr']::uids_t, 1);

delete from addition_types;
insert into addition_types(addition_type_id, descr) values('0', 'Готов подписать договор');
insert into addition_types(addition_type_id, descr) values('1', 'Договор подписан');
insert into addition_types(addition_type_id, descr) values('2', 'Только устная договоренность');
insert into addition_types(addition_type_id, descr) values('3', 'Оставил ПРАЙС');
insert into addition_types(addition_type_id, descr) values('4', 'Отказался');
insert into addition_types(addition_type_id, descr) values('5', 'Зайти позже');

delete from agencies;
insert into agencies(agency_id, descr) values('itm', 'ITM Group');
insert into agencies(agency_id, descr) values('lotsman', 'Lotsman');
insert into agencies(agency_id, descr) values('lt', 'Лидер-Тим');
insert into agencies(agency_id, descr) values('ms', 'Мерчендайзинг Сервис');
insert into agencies(agency_id, descr) values('action', 'Action');

delete from attributes;
insert into attributes(descr) values('Продукты');
insert into attributes(descr) values('Хоз/товары');
insert into attributes(descr) values('Уход за телом и полостью рта');
insert into attributes(descr) values('Декоративная косметика');

delete from audit_criterias;
insert into audit_criterias(audit_criteria_id, descr, wf, row_no) values('0', 'Представленность продукции (ассортимент)', 0.3, 0);
insert into audit_criterias(audit_criteria_id, descr, wf, row_no) values('1', 'Соответствие планограмме', 0.15, 1);
insert into audit_criterias(audit_criteria_id, descr, wf, row_no) values('2', 'Доля полки / Доля в ассортименте', 0.2, 2);
insert into audit_criterias(audit_criteria_id, descr, wf, row_no) values('3', 'Ценники', 0.15, 3);
insert into audit_criterias(audit_criteria_id, descr, wf, mandatory, row_no) values('4', 'ПРОМО', 0.20, 0, 4);

delete from audit_scores;
insert into audit_scores(audit_score_id, descr, score, wf) values('0', '<b>Оценка: 0 баллов</b> (имеются серьезные недостатки)', 0, 0);
insert into audit_scores(audit_score_id, descr, score, wf) values('1', '<b>Оценка: 1 балл</b> (имеются незначительные недостатки)', 1, 0.5);
insert into audit_scores(audit_score_id, descr, score, wf) values('2', '<b>Оценка: 2 балла</b> (недостатки не обнаружены)', 2, 1);

delete from categories;
insert into categories(categ_id, descr, wf, row_no) values('0', 'Зубные пасты', 0.26, 0);
insert into categories(categ_id, descr, wf, row_no) values('1', 'Зубные щётки', 0.21, 1);
insert into categories(categ_id, descr, wf, row_no) values('2', 'Ополаскиватели', 0.07, 2);
insert into categories(categ_id, descr, wf, row_no) values('3', 'Гели для душа', 0.20, 3);
insert into categories(categ_id, descr, wf, row_no) values('4', 'Жидкое мыло', 0.07, 4);
insert into categories(categ_id, descr, wf, row_no) values('5', 'Твердое мыло', 0.07, 5);
insert into categories(categ_id, descr, wf, row_no) values('6', 'Дезодоранты', 0.11, 6);

delete from canceling_types;
insert into canceling_types(canceling_type_id, descr) values('0', 'Временная нетрудоспособность');
insert into canceling_types(canceling_type_id, descr) values('1', 'Отпуск');
insert into canceling_types(canceling_type_id, descr) values('2', 'Участие в конференции');

delete from comment_types;
insert into comment_types(comment_type_id, descr, min_note_length, extra_info, row_no) values('0', 'Объяснение', 5, 'Необходимо ввести в поле дополнительной информации описание проблемы длиной не менее 5 символов.', 0);
insert into comment_types(comment_type_id, descr, photo_needed, extra_info, row_no, hidden) values('1', 'Подтверждение факта посещения', 1, 'Необходимо сделать фотографию входа в торговую точку.', 1, 1);
insert into comment_types(comment_type_id, descr, photo_needed, extra_info) values('2', 'Торговая точка закрыта на учет', 1, 'Необходимо сделать фотографию входа торговой точки');
insert into comment_types(comment_type_id, descr, photo_needed, extra_info) values('3', 'Торговая точка закрыта на ремонт', 1, 'Необходимо сделать фотографию входа торговой точки');
insert into comment_types(comment_type_id, descr) values('4', 'Дебиторская задолженность');
insert into comment_types(comment_type_id, descr) values('5', 'Ответственное лицо отсутствует');

delete from confirmation_types;
insert into confirmation_types(confirmation_type_id, target_type_ids, descr, accomplished)     values('0', array['notice']::uids_t, 'Я понял(-а) данное уведомление', 1);
insert into confirmation_types(confirmation_type_id, target_type_ids, descr)                   values('1', array['reminder']::uids_t, 'Скрыть напоминание');
insert into confirmation_types(confirmation_type_id, target_type_ids, descr, min_note_length)  values('2', array['target:normal','target:strict','target:permanent']::uids_t, 'Задача НЕ выполнена (объяснение от 10 символов)', 10);
insert into confirmation_types(confirmation_type_id, target_type_ids, descr, min_note_length)  values('3', array['target:normal','target:strict','target:permanent']::uids_t, 'Задача выполнена частично (объяснение от 10 символов)', 10);
insert into confirmation_types(confirmation_type_id, target_type_ids, descr, accomplished)     values('4', array['target:normal']::uids_t, 'Задача выполнена ПОЛНОСТЬЮ', 1);
insert into confirmation_types(confirmation_type_id, target_type_ids, descr, photo_needed, accomplished) values('5', array['target:strict']::uids_t, 'Задача выполнена ПОЛНОСТЬЮ (требуется фото)', 1, 1);
insert into confirmation_types(confirmation_type_id, target_type_ids, descr, photo_needed)     values('6', array['target:permanent']::uids_t, 'Задача выполнена ПОЛНОСТЬЮ (требуется фото)', 1);
insert into confirmation_types(confirmation_type_id, target_type_ids, descr, accomplished)     values('7', array['yes:no']::uids_t, 'Нет, т/точка не будет участвовать в акции', 1);
insert into confirmation_types(confirmation_type_id, target_type_ids, descr, accomplished)     values('8', array['yes:no']::uids_t, 'ДА, т/точка будет участвовать в акции', 1);
insert into confirmation_types(confirmation_type_id, target_type_ids, descr, accomplished)     values('9', array['yes:no']::uids_t, 'Неизвестно, уточнить в следующий раз', 0);

delete from countries;
insert into countries(country_id, descr) values('AZ', 'Азербайджан');
insert into countries(country_id, descr) values('AM', 'Армения');
insert into countries(country_id, descr) values('BY', 'Беларусь');
insert into countries(country_id, descr) values('GE', 'Грузия');
insert into countries(country_id, descr) values('KZ', 'Казахстан');
insert into countries(country_id, descr) values('KG', 'Киргизия');
insert into countries(country_id, descr) values('MD', 'Молдавия');
insert into countries(country_id, descr) values('MN', 'Монголия');
insert into countries(country_id, descr) values('TJ', 'Таджикистан');
insert into countries(country_id, descr) values('TM', 'Туркмения');
insert into countries(country_id, descr) values('RU', 'Россия');
insert into countries(country_id, descr) values('UZ', 'Узбекистан');

delete from delivery_types;
insert into delivery_types(delivery_type_id, descr) values('0', 'Доставка поставщиком');
insert into delivery_types(delivery_type_id, descr) values('1', 'Самовывоз заказчиком');

delete from departments;
insert into departments(dep_id, descr) values('0', 'MASS');
insert into departments(dep_id, descr) values('1', 'OTC');

delete from discard_types;
insert into discard_types(discard_type_id, descr, row_no) values('0', 'Ошибочно добавлена в маршрут', 0);
insert into discard_types(discard_type_id, descr) values('1', 'Закрыта на ремонт');
insert into discard_types(discard_type_id, descr) values('2', 'Больше не работает с дистрибутором');
insert into discard_types(discard_type_id, descr) values('3', 'Дебиторская задолженность');

delete from distributors;
insert into distributors(distr_id, descr) values('0', 'Рогов и Копытин, ЗАО');

delete from issues;
insert into issues(issue_id, descr, extra_info, row_no) values('0','Установка мобильного приложения на планшет',
    'На планшете: <br/>1. Открыть браузер и загрузить дистрибутив od.apk с <b>omobus.net</b>.<br/>'||
    '2. Установить загруженноеприложение (в настройках планшета может потребоваться включить [Безопасность] → [Неизвестные источники]).<br/>'||
    '3. Запустить OMOBUS и ввести учетные параметры (выдаются руководителем).',0);
insert into issues(issue_id, descr, extra_info, row_no) values('1','Подключение к web-консоли',
    '1. Для подключения используются те же учетные параметры, что и для подключения к мобильному приложению.<br/>'||
    '2. Рекомендуется использовать Google Chrome или Mozilla Firefox.<br/>',1);
insert into issues(issue_id, descr, extra_info, row_no) values('2','Смена пользователя мобильного приложения на планшете',
    '<b>ВНИМАНИЕ</b>: ПРЕДВАРИТЕЛЬНО <b>НЕОБХОДИМО ОТПРАВИТЬ</b> ВСЕ ДАННЫЕ.<br/>'||
    '1. Открыть настройки планшета.<br/>'||
    '2. Выбрать [Диспетчер приложений] → [Загружено] → [OMOBUS].<br/>'||
    '3. Нажать [Остановить].<br/>'||
    '4. Нажать [Память] → [Очистить данные].<br/>'||
    '5. Запустить OMOBUS и ввести новые учетные параметры.',2);
insert into issues(issue_id, descr, extra_info, row_no) values('3','НЕТ позиции',
    'Позиция фиксируется только в рабочее время (с 8:00 до 19:00). Также позиция не определяется в помещении.<br/>'||
    'Необходимо проверить настройки в планшете: [Расположение] → [Режим] должно быть выбрано [<b>Только GPS</b>].',3);
insert into issues(issue_id, descr, extra_info, row_no) values('4','НЕТ обмена данными',
    'Запросить: 1. <b>дату синхронизации</b> справочников, 2. <b>количество неотправленных</b> документов или активностей.<br/>'||
    'Необходимо проверить настройки в планшете: 1. выключить [WiFi], 2. включить [Мобильный трафик].'||
    'Выполнить повторную синхронизацию данных. Если не помогает — перезагрузить планшет.',4);
insert into issues(issue_id, descr, extra_info, row_no) values('5','Отсутствует или неверный маршрут',
    'Данная проблема решается через непосредственного руководителя.',5);
insert into issues(issue_id, descr, extra_info, row_no) values('6','Задвоенные т/точки в маршруте',
    'Необходимо запросить: 1. дату маршрута, 2. название т/точки, 3. адрес т/точки. ',6);
insert into issues(issue_id, descr, extra_info, row_no) values('7','История маршрутов',
    '[Начать рабочий день] → [История марщрутов]<br/>Данные в истории маршрутов <b>обновляются 1 раз в 2 часа.</b>',7);
insert into issues(issue_id, descr, extra_info, row_no) values('8','Отмена маршрута',
    '[Начать рабочий день] → [Отмена маршрута]<br/>'||
    'Отмена маршрута <b>автоматически аннулируется</b> при выполнении плановых посещений. Отмену маршрута за прошлые периоды может сделать руководитель.',8);
insert into issues(issue_id, descr, extra_info, row_no) values('9','Отложить посещение',
    'Отложенные посещения показываются в маршруте <b>в течении 7 календарных дней</b> или до момента появления этой т/точки в плановом маршруте.',9);
insert into issues(issue_id, descr, extra_info, row_no) values('10','Внеплановое посещение',
    '[Начать рабочий день] → [Начать маршрут] → [ … ] → [Внеплановое посещение]',10);
insert into issues(issue_id, descr, extra_info) values('12','ДРУГОЕ',
    'Необходимо запросить <b>детальное описание</b> проблемы.');

delete from job_titles;
insert into job_titles(job_title_id, descr) values('0', 'Заведующий');
insert into job_titles(job_title_id, descr) values('1', 'Фармацевт');

delete from order_params;
insert into order_params(distr_id, descr) values('0', 'Деньги забрал');
insert into order_params(distr_id, descr) values('0', 'Любой другой параметр');

delete from oos_types;
insert into oos_types(oos_type_id, descr, row_no) values('0', 'Мало продукции в наличии (1-2 шт)', 0);
insert into oos_types(oos_type_id, descr, row_no) values('1', 'Продукт заблокирован для заказа', 1);
insert into oos_types(oos_type_id, descr, row_no) values('2', 'Виртуальные остатки, а именно товара нет в наличии, но по базе они присутствуют', 2);
insert into oos_types(oos_type_id, descr, row_no) values('3', 'Продукт заказан или ожидается поставка', 3);
insert into oos_types(oos_type_id, descr, row_no) values('4', 'Продукт на складе, требуется мерчендайзинг', 4);
insert into oos_types(oos_type_id, descr, row_no) values('5', 'Не выяснил(-а) причину Out-of-Stock', 5);
insert into oos_types(oos_type_id, descr) values('9', 'ДРУГОЕ');

delete from order_types;
insert into order_types(order_type_id, descr, row_no) values('0', 'Основной', 0);
insert into order_types(order_type_id, descr, row_no) values('1', 'Бонусный', 1);

delete from ownership_types;
insert into ownership_types(ownership_type_id, descr, row_no) values('0', 'Собственность производителя', 0);
insert into ownership_types(ownership_type_id, descr, row_no) values('1', 'Cобственность клиента', 1);

delete from payment_methods;
insert into payment_methods(payment_method_id, descr, row_no) values('0', 'Безналичная оплата', 0);
insert into payment_methods(payment_method_id, descr, row_no) values('1', 'Оплата наличными', 1);
insert into payment_methods(payment_method_id, descr, row_no, encashment) values('2', 'Оплата наличными (фиксированная сумма)', 2, 1);
insert into payment_methods(payment_method_id, descr, row_no) values('3', 'Оплата наличными (точно по сумме документа)', 3);

delete from pending_types;
insert into pending_types(pending_type_id, descr, row_no) values('0', 'Нет успеваю выполнить посещение', 0);
insert into pending_types(pending_type_id, descr) values('1', 'Торговая точка закрыта на ремонт');
insert into pending_types(pending_type_id, descr) values('2', 'Ревизия в торговой точке');
insert into pending_types(pending_type_id, descr) values('3', 'Отсутствует контактное лицо');

delete from photo_types;
insert into photo_types(photo_type_id, descr, row_no) values('0', 'Основное фото', 0);
insert into photo_types(photo_type_id, descr, row_no) values('b', 'ДО выкладки продукции', 1);
insert into photo_types(photo_type_id, descr, row_no) values('a', 'ПОСЛЕ выкладки продукции', 2);

delete from placements;
insert into placements(placement_id, descr, row_no) values('0', 'ПОЛКА (основная выкладка)', 0);
insert into placements(placement_id, descr, row_no) values('1', 'Полка на торце', 1);
insert into placements(placement_id, descr, row_no) values('2', 'Бренд-полка', 2);
insert into placements(placement_id, descr, row_no) values('3', 'Дополнительное место продаж', 3);
insert into placements(placement_id, descr) values('4', 'Горячая (прикассовая) зона');

delete from rating_scores;
insert into rating_scores(rating_score_id, descr, score, wf) values('0', '<b>Оценка: 0 баллов</b> (имеются серьезные недостатки)', 0, 0);
insert into rating_scores(rating_score_id, descr, score, wf) values('1', '<b>Оценка: 1 балл</b> (имеются незначительные недостатки)', 1, 0.5);
insert into rating_scores(rating_score_id, descr, score, wf) values('2', '<b>Оценка: 2 балла</b> (недостатки не обнаружены)', 2, 1);

delete from receipt_types;
insert into receipt_types(receipt_type_id, descr) values('0', 'Основной платеж');
insert into receipt_types(receipt_type_id, descr) values('1', 'Платеж по второй схеме');

delete from reclamation_types;
insert into reclamation_types(reclamation_type_id, descr) values('0', 'Повреждение упаковки');
insert into reclamation_types(reclamation_type_id, descr) values('1', 'Нарушение комплектации');
insert into reclamation_types(reclamation_type_id, descr) values('2', 'Брак');
insert into reclamation_types(reclamation_type_id, descr) values('3', 'Истек срок годности');

delete from support;
insert into support(sup_id, descr, email) 
    values('0', 'Техническая поддержка', 'support@omobus.net');
insert into support(sup_id, descr, phone, email, country_id, row_no) 
    values('1', 'Поддержка пользователей', '8-800-333-93-50', 'hd@omobus.net', 'RU', 1);
insert into support(sup_id, descr, phone, email, country_id, row_no) 
    values('2', 'Поддержка пользователей', '8-800-100-52-64', 'hd@omobus.net', 'KZ', 2);
insert into support(sup_id, descr, phone, email, country_id, row_no) 
    values('3', 'Поддержка пользователей', '8-8-200-073-00-31', 'hd@omobus.net', 'BY', 3);

delete from sysholidays;
insert into sysholidays(h_date, country_id, descr) values('2019-01-01', 'RU', 'Новогодние каникулы');
insert into sysholidays(h_date, country_id, descr) values('2019-01-02', 'RU', 'Новогодние каникулы');
insert into sysholidays(h_date, country_id, descr) values('2019-01-03', 'RU', 'Новогодние каникулы');
insert into sysholidays(h_date, country_id, descr) values('2019-01-04', 'RU', 'Новогодние каникулы');
insert into sysholidays(h_date, country_id, descr) values('2019-01-07', 'RU', 'Рождество Христово');
insert into sysholidays(h_date, country_id, descr) values('2019-01-08', 'RU', 'Новогодние каникулы');
insert into sysholidays(h_date, country_id, descr) values('2019-03-08', 'RU', 'Международный женский день');
insert into sysholidays(h_date, country_id, descr) values('2019-05-01', 'RU', 'Праздник Весны и Труда');
insert into sysholidays(h_date, country_id, descr) values('2019-05-02', 'RU', 'Новогодние каникулы (перенос с 5 января на 2 мая)');
insert into sysholidays(h_date, country_id, descr) values('2019-05-03', 'RU', 'Новогодние каникулы (перенос с 6 января на 3 мая)');
insert into sysholidays(h_date, country_id, descr) values('2019-05-09', 'RU', 'День Победы');
insert into sysholidays(h_date, country_id, descr) values('2019-05-10', 'RU', 'День защитника Отечества (перенос с 23 февраля на 10 мая)');
insert into sysholidays(h_date, country_id, descr) values('2019-06-12', 'RU', 'День России');
insert into sysholidays(h_date, country_id, descr) values('2019-11-04', 'RU', 'День народного единства');
insert into sysholidays(h_date, country_id, descr) values('2019-01-01', 'KZ', 'Новый год');
insert into sysholidays(h_date, country_id, descr) values('2019-01-02', 'KZ', 'Новый год');
insert into sysholidays(h_date, country_id, descr) values('2019-01-07', 'KZ', 'Рождество Христово');
insert into sysholidays(h_date, country_id, descr) values('2019-03-08', 'KZ', 'Международный женский день');
insert into sysholidays(h_date, country_id, descr) values('2019-03-21', 'KZ', 'Наурыз мейрамы');
insert into sysholidays(h_date, country_id, descr) values('2019-03-22', 'KZ', 'Наурыз мейрамы');
insert into sysholidays(h_date, country_id, descr) values('2019-03-23', 'KZ', 'Наурыз мейрамы');
insert into sysholidays(h_date, country_id, descr) values('2019-05-01', 'KZ', 'Праздник единства народа Казахстана');
insert into sysholidays(h_date, country_id, descr) values('2019-05-07', 'KZ', 'День защитника Отечества');
insert into sysholidays(h_date, country_id, descr) values('2019-05-09', 'KZ', 'День Победы');
insert into sysholidays(h_date, country_id, descr) values('2019-07-06', 'KZ', 'День столицы');
insert into sysholidays(h_date, country_id, descr) values('2019-08-30', 'KZ', 'День Конституции');
insert into sysholidays(h_date, country_id, descr) values('2019-12-01', 'KZ', 'День Первого Президента');
insert into sysholidays(h_date, country_id, descr) values('2019-12-16', 'KZ', 'День Независимости Казахстана');
insert into sysholidays(h_date, country_id, descr) values('2019-12-17', 'KZ', 'День Независимости Казахстана');
insert into sysholidays(h_date, country_id, descr) values('2019-01-01', 'BY', 'Новый год');
insert into sysholidays(h_date, country_id, descr) values('2019-01-07', 'BY', 'Рождество Христово (православное)');
insert into sysholidays(h_date, country_id, descr) values('2019-03-08', 'BY', 'День женщин');
insert into sysholidays(h_date, country_id, descr) values('2019-04-25', 'BY', 'Радуница - день поминовения усопших');
insert into sysholidays(h_date, country_id, descr) values('2019-05-01', 'BY', 'Праздник труда');
insert into sysholidays(h_date, country_id, descr) values('2019-05-09', 'BY', 'День Победы');
insert into sysholidays(h_date, country_id, descr) values('2019-07-03', 'BY', 'День Независимости Республики Беларусь');
insert into sysholidays(h_date, country_id, descr) values('2019-11-07', 'BY', 'День Октябрьской революции');
insert into sysholidays(h_date, country_id, descr) values('2019-12-25', 'BY', 'Рождество Христово (католическое)');
insert into sysholidays(h_date, country_id, descr) values('2019-01-01', 'UZ', 'Новый год');
insert into sysholidays(h_date, country_id, descr) values('2019-01-14', 'UZ', 'День защитника Отечества');
insert into sysholidays(h_date, country_id, descr) values('2019-03-08', 'UZ', 'День женщин');
insert into sysholidays(h_date, country_id, descr) values('2019-03-21', 'UZ', 'Праздник Навруз');
insert into sysholidays(h_date, country_id, descr) values('2019-05-09', 'UZ', 'День Памяти и Почестей');
insert into sysholidays(h_date, country_id, descr) values('2019-09-01', 'UZ', 'День Независимости');
insert into sysholidays(h_date, country_id, descr) values('2019-10-01', 'UZ', 'День учителя и наставника');
insert into sysholidays(h_date, country_id, descr) values('2019-12-08', 'UZ', 'День Конституции');
insert into sysholidays(h_date, country_id, descr) values('2019-01-01', 'AZ', 'Новый год');
insert into sysholidays(h_date, country_id, descr) values('2019-01-02', 'AZ', 'Новый год');
insert into sysholidays(h_date, country_id, descr) values('2019-03-08', 'AZ', 'Женский день');
insert into sysholidays(h_date, country_id, descr) values('2019-03-21', 'AZ', 'Праздник Новруз');
insert into sysholidays(h_date, country_id, descr) values('2019-03-22', 'AZ', 'Праздник Новруз');
insert into sysholidays(h_date, country_id, descr) values('2019-03-23', 'AZ', 'Праздник Новруз');
insert into sysholidays(h_date, country_id, descr) values('2019-03-24', 'AZ', 'Праздник Новруз');
insert into sysholidays(h_date, country_id, descr) values('2019-03-25', 'AZ', 'Праздник Новруз');
insert into sysholidays(h_date, country_id, descr) values('2019-05-09', 'AZ', 'День победы над фашизмом');
insert into sysholidays(h_date, country_id, descr) values('2019-05-28', 'AZ', 'День Республики');
insert into sysholidays(h_date, country_id, descr) values('2019-06-15', 'AZ', 'Праздник Рамазан');
insert into sysholidays(h_date, country_id, descr) values('2019-06-18', 'AZ', 'Праздник Рамазан (перенос с 16 на 18 июня)');
insert into sysholidays(h_date, country_id, descr) values('2019-06-26', 'AZ', 'День Вооруженных сил Азербайджанской Республики');
insert into sysholidays(h_date, country_id, descr) values('2019-08-22', 'AZ', 'Праздник Гурбан');
insert into sysholidays(h_date, country_id, descr) values('2019-08-23', 'AZ', 'Праздник Гурбан');
insert into sysholidays(h_date, country_id, descr) values('2019-11-09', 'AZ', 'День Государственного флага Азербайджанской Республики');
insert into sysholidays(h_date, country_id, descr) values('2019-12-31', 'AZ', 'День солидарности азербайджанцев мира');

insert into sysholidays(h_date, country_id, descr) values('2019-01-01', 'KG', 'Новый год');
insert into sysholidays(h_date, country_id, descr) values('2019-01-07', 'KG', 'Рождество Христово');
insert into sysholidays(h_date, country_id, descr) values('2019-02-23', 'KG', 'День защитника Отечества');
insert into sysholidays(h_date, country_id, descr) values('2019-03-08', 'KG', 'Женский день');
insert into sysholidays(h_date, country_id, descr) values('2019-03-21', 'KG', 'Народный праздник Нооруз');
insert into sysholidays(h_date, country_id, descr) values('2019-05-01', 'KG', 'Праздник труда');
insert into sysholidays(h_date, country_id, descr) values('2019-05-05', 'KG', 'День Конституции Кыргызской Республики');
insert into sysholidays(h_date, country_id, descr) values('2019-05-09', 'KG', 'День победы над фашизмом');
insert into sysholidays(h_date, country_id, descr) values('2019-08-31', 'KG', 'День независимости Кыргызской Республики');
insert into sysholidays(h_date, country_id, descr) values('2019-11-07', 'KG', 'Дни истории и памяти предков');
insert into sysholidays(h_date, country_id, descr) values('2019-11-08', 'KG', 'Дни истории и памяти предков');

delete from syswdmv;
--insert into syswdmv(f_date, t_date, country_id, descr) values('20XX-XX-XX', '20XX-XX-XX', 'XX', 'Перенос рабочего дня с XX на XX января.');

delete from target_types;
insert into target_types(target_type_id, descr, row_no) values('notice', 'Напоминание', 4);
insert into target_types(target_type_id, descr, row_no) values('reminder', 'Напоминание на каждом посещении', 3);
insert into target_types(target_type_id, descr, row_no) values('target:strict', 'ЗАДАЧА до подтверждения с ОБЯЗАТЕЛЬНОЙ фотографией', 1);
insert into target_types(target_type_id, descr, row_no) values('target:normal', 'ЗАДАЧА до подтверждения', 0);
insert into target_types(target_type_id, descr, row_no) values('target:permanent', 'ЗАДАЧА на каждом посещении с ОБЯЗАТЕЛЬНОЙ фотографией', 2);
insert into target_types(target_type_id, descr, row_no, selectable) values('yes:no', 'Анкетирование (ответ Да или Нет)', 90, 0);

delete from testing_scores;
insert into testing_scores(testing_score_id, descr, score, wf) values('0', '<b>Оценка: 0 баллов</b> (имеются серьезные недостатки)', 0, 0);
insert into testing_scores(testing_score_id, descr, score, wf) values('1', '<b>Оценка: 1 балл</b> (имеются незначительные недостатки)', 1, 0.5);
insert into testing_scores(testing_score_id, descr, score, wf) values('2', '<b>Оценка: 2 балла</b> (недостатки не обнаружены)', 2, 1);

delete from training_types;
insert into training_types(training_type_id, descr, personal) values('0', 'Индивидуальное', 1);
insert into training_types(training_type_id, descr) values('1', 'Фармкружок');

delete from wish_days;
insert into wish_days(wish_day_id, descr, days, row_no) values('mon', 'Понедельник', array[1,0,0,0,0,0,0], 1);
insert into wish_days(wish_day_id, descr, days, row_no) values('tue', 'Вторник', array[0,1,0,0,0,0,0], 2);
insert into wish_days(wish_day_id, descr, days, row_no) values('wed', 'Среда', array[0,0,1,0,0,0,0], 3);
insert into wish_days(wish_day_id, descr, days, row_no) values('thu', 'Четверг', array[0,0,0,1,0,0,0], 4);
insert into wish_days(wish_day_id, descr, days, row_no) values('fri', 'Пятница', array[0,0,0,0,1,0,0], 5);
insert into wish_days(wish_day_id, descr, days, row_no, hidden) values('sat', 'Суббота', array[0,0,0,0,0,1,0], 6, 1);
insert into wish_days(wish_day_id, descr, days, row_no, hidden) values('sun', 'Воскресенье', array[0,0,0,0,0,0,1], 0, 1);

delete from wish_weeks;
insert into wish_weeks(wish_week_id, descr, weeks, row_no) values('0', 'Каждую неделю цикла', array[1,1,1,1], 0);
insert into wish_weeks(wish_week_id, descr, weeks, row_no) values('1', '1-я и 3-я недели цила', array[1,0,1,0], 1);
insert into wish_weeks(wish_week_id, descr, weeks, row_no) values('2', '2-я и 4-я недели цила', array[0,1,0,1], 2);
insert into wish_weeks(wish_week_id, descr, weeks, row_no) values('3', '1-я неделя цила', array[1,0,0,0], 3);
insert into wish_weeks(wish_week_id, descr, weeks, row_no) values('4', '2-я неделя цила', array[0,1,0,0], 4);
insert into wish_weeks(wish_week_id, descr, weeks, row_no) values('5', '3-я неделя цила', array[0,0,1,0], 5);
insert into wish_weeks(wish_week_id, descr, weeks, row_no) values('6', '4-я неделя цила', array[0,0,0,1], 6);

delete from "L10n";
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','1','','Январь');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','2','','Февраль');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','3','','Март');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','4','','Апрель');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','5','','Май');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','6','','Июнь');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','7','','Июль');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','8','','Август');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','9','','Сентябрь');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','10','','Октябрь');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','11','','Ноябрь');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','12','','Декабрь');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','1','genitive','января');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','2','genitive','февраля');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','3','genitive','марта');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','4','genitive','апреля');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','5','genitive','мая');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','6','genitive','июня');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','7','genitive','июля');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','8','genitive','августа');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','9','genitive','сентября');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','10','genitive','октября');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','11','genitive','ноября');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','month_name','12','genitive','декабря');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','aKPI','','audit','Результаты аудита от $(fix_date):');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','KPI','','vc','План посещений/$(month_name) (<i>$(completed) из $(total)</i>):');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','KPI','','vc:alert', 'Сомнительных посещений (менее $(min_duration) мин.):');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','canceling/caption:new','Отмена маршрута');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','canceling/body:new','<html><body>$(u_name) отменил(-а) маршрут с <b>$(b_date)</b> по <b>$(e_date)</b> (причина отмены: <i>$(canceling_type)</i>; примечание: $(doc_note)).<br/><br/>ВНИМАНИЕ. В случае выполнения плановой активности, отмена маршрута автоматически аннулируется. Восстановить аннулированную отмену маршрута можно через руководителя или службу п/пользователей OMOBUS.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','canceling/body:notice','<html><body>$(u_name), $(fix_dt) отменил(-а) маршрут с <b>$(b_date)</b> по <b>$(e_date)</b> (причина отмены: <i>$(canceling_type)</i>; примечание: $(doc_note)). В том случае, если Вы считаете, что отмена маршрута была сделана ошибочно, Вы можете её аннулировать через web-console OMOBUS.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','canceling/caption:revoke','Отмена маршрута (аннулирование)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','canceling/body:revoke','<html><body>$(u_name) аннулировал(-а) отмену маршрута на $(route_date).<br/><br/>ВНИМАНИЕ. Восстановить аннулированную отмену маршрута можно через руководителя или службу п/пользователей OMOBUS.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','canceling/body:autorevoke','<html><body>В связи с выполнением плановой активности, отмена маршрута на $(route_date) была автоматически аннулирована.<br/><br/>ВНИМАНИЕ. Восстановить аннулированную отмену маршрута можно через руководителя или службу п/пользователей OMOBUS.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','canceling/caption:restore','Отмена маршрута (восстановление)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','canceling/body:restore','<html><body>$(u_name) восстановил(-а) отмену маршрута на $(route_date).</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','confirmation/caption','Выполнение задачи: $(subject)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','confirmation/body','<html><body>$(u_name), $(fix_dt) в <b>$(a_name) $(address)</b> подтвердил(-а) выполнение задачи <i>$(subject)</i>:<br/><br/>$(body)<br/><br/>$(confirm_type).<br/>Примечание: $(doc_note).</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','deletion/caption:new','Удаление клиента (заявка): $(a_name)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','deletion/body:new','<html><body>$(u_name), $(fix_dt) создал(-а) заявку на удаление <i>$(a_name) $(address)</i>.<br/><br/>ВНИМАНИЕ. В том случае, если заявка создана по ошибке, отменить её может Ваш руководитель или служба п/пользователей OMOBUS.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','deletion/body:notice','<html><body>$(u_name), $(fix_dt) создал(-а) заявку на удаление <i>$(a_name) $(address)</i>. Вам необходимо подтвердить или отклонить данную заявку через web-console OMOBUS.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','deletion/caption:reject','Удаление клиента (отмена): $(a_name)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','deletion/body:reject','<html><body>$(u_name) отменил(-а) удаление <i>$(a_name) $(address)</i>.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','deletion/caption:validate','Удаление клиента (подтверждение): $(a_name)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','deletion/body:validate','<html><body>$(u_name) подтвердил(-а) удаление <i>$(a_name) $(address)</i>.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','discard/caption:new','Исключение из маршрута (заявка): $(a_name)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','discard/body:notice','<html><body>$(u_name), $(fix_dt) сформировал(-а) заявку на исключение <i>$(a_name) $(address)</i> из маршрута на <i>$(route_date)</i>. Вам необходимо подтвердить или отклонить данную заявку через web-console OMOBUS.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','discard/caption:reject','Исключение из маршрута (отмена): $(a_name)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','discard/body:reject','<html><body>$(u_name) отклонил(-а) исключение <i>$(a_name) $(address)</i> из маршрута на <i>$(route_date)</i>.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','discard/caption:validate','Исключение из маршрута (подтверждение): $(a_name)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','discard/body:validate','<html><body>$(u_name) подвердил(-а) исключение <i>$(a_name) $(address)</i> из маршрута на <i>$(route_date)</i>.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','gps_off/caption','НЕ ОТКЛЮЧАЙТЕ ДАТЧИК ОПРЕДЕЛЕНИЯ МЕСТОПОЛОЖЕНИЯ');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','gps_off/body', 
    '<html><body>$(fix_dt) зафиксировано <b>отключение</b> датчика определения местоположения или датчик был выключен в момент запуска процедуры контроля перемещений. ' ||
    'Для того, что-бы избежать спорных ситуаций, рекомендуется <i>незамедлительно включить</i> датчик определения местоположения. ' || 
    'Для этого:<br />' ||
    '&nbsp;&nbsp;&nbsp;1. зайдите в настройки планшета;<br />' ||
    '&nbsp;&nbsp;&nbsp;2. выберите пункт «Местоположение»;<br />' ||
    '&nbsp;&nbsp;&nbsp;3. включите датчик определения местоположения.<br />' ||
    '<br />'||
    'ВНИМАНИЕ. <b>Режим работы</b> датчика определения местоположения должен быть настроен на: «<b>По спутникам GPS</b>».' ||
    '</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','gps_violation/caption','Отключение датчика местоположения ($(dev_login))');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','gps_violation/body','$(fix_dt) на устройстве $(dev_login) (сотрудник: $(u_name)) зафиксировано отключение датчика местоположения. Контроль перемещений сотрудника заблокирована.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','order/caption','Заказ продукции $(doc_no) (принят)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','order/body','<html><body>В обработку принят заказ продукции $(doc_no) на сумму <b>$(amount)</b> (доставка: <b>$(delivery_date)</b>, тип: $(order_type)) от <i>$(a_name) $(address)</i>. Отгрузка будет осуществляться со склада <i>$(d_name) [$(w_name)]</i>.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','reclamation/caption','Возврат продукции $(doc_no) (принят)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','reclamation/body','<html><body>В обработку принят возврат продукции $(doc_no) на сумму <b>$(amount)</b> (дата возврата: <b>$(return_date)</b>) от <i>$(a_name) $(address)</i>. Возврат будет осуществляться на склад $(d_name).</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','remark/caption:accept','Подтверждение задачи принято');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','remark/caption:reject','Подтверждение задачи отклонено');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','remark/body:accept0','<html><body>$(u_name) принял(-а) подтверждение выполнения задачи <i>$(sub)</i> в <i>$(a_name) $(address)</i> сформированное <i>$(fix_dt)</i>. Дополнительная информация:<br/><br/><b>$(note)</b><br/></body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','remark/body:accept1','<html><body>$(u_name) принял(-а) подтверждение выполнения задачи <i>$(sub)</i> в <i>$(a_name) $(address)</i> сформированное <i>$(fix_dt)</i>.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','remark/body:reject0','<html><body>$(u_name) отклонил(-а) подтверждение выполнения задачи <i>$(sub)</i> в <i>$(a_name) $(address)</i> сформированное <i>$(fix_dt)</i>. Указана следующая причина:<br/><br/><b>$(note)</b><br/></body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','remark/body:reject1','<html><body>$(u_name) отклонил(-а) подтверждение выполнения задачи <i>$(sub)</i> в <i>$(a_name) $(address)</i> сформированное <i>$(fix_dt)</i>. Указана следующая причина:<br/><br/><b>$(note)</b><br/><br/>Задача поставлена повторно. В рамках ближайшего посещения клиента необходимо отчитаться об устранении выявленных замечаний.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','resolution/caption','Резолюция на заявку #$(ticket_id).');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','resolution/body','<html><body>От $(inserted_ts)<br/>$(doc_note)</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','sched/caption','Планировщик рабочего времени');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','sched/body','Не забудьте запланировать своё рабочее время на $(date).');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','target/caption','Новая задача: $(subject)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','target/body','<html><body>$(u_name) $(fix_dt) в рамках выполнения активности $(activity_type) в <i>$(a_name) $(address)</i> поставил(-а) следующую задачу:<br/><br/>$(body)<br/><br/>Срок действия с <b>$(b_date)</b> по <b>$(e_date)</b>.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','ticket/caption','Заявка #$(ticket_id)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','ticket/caption:closed','Заявка #$(ticket_id) (ЗАКРЫТА)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','ticket/body','<html><body>ВНИМАНИЕ. Результаты решения данной проблемы будут высланы отдельным уведомлением (резолюцией).<br/><br/>Зарегистрировано: $(inserted_ts).<br/>Проблема: $(issue).<br/>$(doc_note)</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','ticket/body:closed','<html><body>Зарегистрировано: $(inserted_ts).<br/>Проблема: $(issue).<br/>$(doc_note)</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','tm_change/caption','НЕ МЕНЯЙТЕ ВРЕМЯ НА УСТРОЙСТВЕ');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','tm_change/body', 
    '<html><body>$(fix_dt) зафиксировано <b>изменение веремени</b> на устройстве. <i>Это серьезное нарушение может повлиять на результаты Вашей работы.</i> ' ||
    'Для того, что-бы в дальнейшем избежать возникновение спорных ситуаций, необходимо полностью исключить практику изменения времени на устройстве за исключением ' ||
    'тех случаев, когда данная процедура согласована с Вашим непосредственным руководителем.<br/>' ||
    '<br />'||
    'ВНИМАНИЕ. В том случае, если Вы не меняли время, необходимо в настройках устройства отключить режим энергосбережения и автоматическую синхронизацию времени и ' ||
    'часового пояса по данным сети. Отключить автоматическую синхронизацию времени можно следующим образом:<br/>' ||
    '&nbsp;&nbsp;&nbsp;1. зайдите в настройки планшета;<br />' ||
    '&nbsp;&nbsp;&nbsp;2. выберите пункт «Дата и время»;<br />' ||
    '&nbsp;&nbsp;&nbsp;3. отключите «Дата и время сети»;<br />' ||
    '&nbsp;&nbsp;&nbsp;4. отключите «Часовой пояс сети»;<br />' ||
    '&nbsp;&nbsp;&nbsp;5. установите корректное значение часового пояса и времени.' ||
    '</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','tm_violation/caption','Изменение времени ($(dev_login))');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','tm_violation/body','$(fix_dt) на устройстве $(dev_login) (сотрудник: $(u_name)) зафиксировано изменение времени.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','user_activity/caption','Нарушение регламента посещения');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','user_activity/body','<html><body>$(a_type) <i>$(a_name) $(address)</i> от <i>$(b_dt)</i> выполнено со следующими нарушениями регламента:<br/><br/>$(violations).<br/><br/>Рекомендуется не допускать нарушений регламента посещения в будущем.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','user_activity/violation/duration','&nbsp;&nbsp;&nbsp;&bull; продолжительность менее $(duration) минут');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','user_activity/violation/b_distance','&nbsp;&nbsp;&nbsp;&bull; начато более чем за $(distance) м. от адреса клиента');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','user_activity/violation/e_distance','&nbsp;&nbsp;&nbsp;&bull; закончено более чем за $(distance) м. от адреса клиента');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','wish/caption:new','Включение в маршрут (заявка): $(a_name)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','wish/body:notice','<html><body>$(u_name), $(fix_dt) сформировал(-а) заявку на включение <i>$(a_name) $(address)</i> в маршрута. Вам необходимо подтвердить или отклонить данную заявку через web-console OMOBUS.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','wish/caption:reject','Включение в маршрута (отмена): $(a_name)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','wish/body:reject','<html><body>$(u_name) отклонил(-а) включение <i>$(a_name) $(address)</i> в маршрут.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','wish/caption:validate','Включение в маршрут (подтверждение): $(a_name)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','wish/body:validate','<html><body>$(u_name) подвердил(-а) включение <i>$(a_name) $(address)</i> в маршрут.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','zstatus/caption:accept','Посещение принято');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','zstatus/caption:reject','Посещение отклонено');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','zstatus/body:accept0','<html><body>$(u_name) принял(-а) $(a_type) <i>$(a_name) $(address)</i> от <i>$(fix_date)</i>. Дополнительная информация:<br/><br/><b>$(note)</b><br/></body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','zstatus/body:accept1','<html><body>$(u_name) принял(-а) $(a_type) <i>$(a_name) $(address)</i> от <i>$(fix_date)</i>.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','zstatus/body:reject','<html><body>$(u_name) отклонил(-а) $(a_type) <i>$(a_name) $(address)</i> от <i>$(fix_date)</i>. Указана следующая причина:<br/><br/><b>$(note)</b><br/></body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','TTD/caption:order','Заказ продукции $(doc_no) (доставлен)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','TTD/caption:reclamation','Возврат продукции $(doc_no) (доставлен)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','TTD/body:accepted','<html><body>Дистрибьютор подтвердил получение документа $(doc_no). Номер(-а) документа(-ов) в учетной системе дистрибьютора: <b>$(erp_no)</b>.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','evmail','','TTD/body:delivered','<html><body>Документ $(doc_no) успешно доставлен дистрибьютору.<br/><br/>ВНИМАНИЕ. Дальнейшее состояние документа уточняйте у сотрудников дистрибьютора.</body></html>');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','my_routes','','pending','Необходимо выполнить до $(e_date) (включительно).');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','my_routes','','pending/today','Сегодня <b>последний день</b> действия отложенного посещения. Не забудьте посетить данного клиента и зафиксировать все требуемые данные.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','orders_history','','extra','Тип: $(type). Склад: $(wareh). Доставка: <b>$(delivery_date)</b> ($(delivery_note)). $(note)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','reminder','','audit','Необходимо срочно устранить замечания, выявленные в ходе аудита размещения продукции от $(fix_date) в $(a_name) $(address) (<i>автор: $(u_name)</i>).');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','reminder','','joint_route/caption','Результаты совместного маршрута');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','reminder','','joint_route/body', 'ИТОГОВАЯ ОЦЕНКА от $(fix_date): <b>$(sla)%</b><br/>Автор: $(u_name)<br/><br/><i>(сильные стороны обучаемого)</i><br/>$(note0)<br/><br/><i>(области для развития)</i><br/>$(note1)<br/><br/><i>(рекомендации для развития)</i><br/>$(note2)');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','reminder','','sched/caption','Планировщик рабочего времени');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','reminder','','sched/coaching:today','Сегодня, $(date) у Вас запланированы следующие полевые обучения:<br/><br/>$(timeline).');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','reminder','','sched/coaching:tomorrow','Завтра, $(date) у Вас запланированы следующие полевые обучения:<br/><br/>$(timeline).');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','reminder','','target','$(u_name) затребовал приоритетное выполнение задач, поставленных $(fix_date) в $(a_name) $(address).');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_cycles','','','%1$s день %2$s недели %3$s цикла');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','advt','Наличие рекламных материалов.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','audit','Аудит категории $(categ): $(sla)%.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','checkups','Осмотр т/зала или склада.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','comment','Комментарий: $(doc_note) [$(comment_type)].');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','contact','Новый контакт: $(surname) $(name).');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','deletion', 'Заявка на удаление: $(doc_note).');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','equipment','Новое т/оборудование: $(equipment_type), serial: $(serial_number).');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','extra', 'Доля доп/места $(placement): $(soe)%.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','orders', 'Заказано продуктов: $(rows) на сумму <b>$(amount)</b>.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','oos', 'Выявление причин Out-of-Stock.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','photo', 'Фото $(placement) $(brand) $(photo_type) ($(rows) шт.).');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','presences', 'Представленность продукции.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','presentation', 'Презентация кон/потребителям: $(participants) чел.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','prices', 'Мониторинг цен.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','rating', 'Оценка работы [$(u_name)]: $(assessment) / $(sla)%.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','receipt', 'ПКО: $(amount).');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','reclamations', 'Возвращено продуктов: $(rows) на сумму <b>$(amount)</b>.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','shelf', 'Доля полки / доля в ассортименте в категории $(categ): $(sos)% / $(soa)%.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','stocks', 'Ревизия складских остатков.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','target', 'Задача: $(subject).');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','testing', 'Тестирование $(surname) $(name): $(sla)%.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','route_history','','training', 'Обучение персонала: $(training_type).');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','targets','','audit','В ходе выполнения аудита размещения продукции от <i>$(fix_date)</i> обнаружены следующие <b><i>нарушения</i></b>:<br/><br/>$(violations)<br/><br/>Итоговый SLA: <b>$(sla)%</b>.<br/>Автор: <b>$(u_name)</b>.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','targets','','audit/positive','В ходе выполнения аудита размещения продукции от <i>$(fix_date)</i> нарушений <b><i>НЕ выявлено</i></b>:<br/><br/>$(violations)<br/><br/>Автор: <b>$(u_name)</b>.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','targets','','confirmation','На основе подтверждения выполнения задачи, <i>$(fix_date)</i> была поставлена новая задача:<br/><br/>$(msg)<br/><br/>Автор: <b>$(u_name)</b>.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','targets','','new','В рамках выполнения активности $(activity_type), <i>$(fix_date)</i> была поставлена следующая задача:<br/><br/>$(body)<br/><br/>Автор: <b>$(u_name)</b>.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','targets','','photo','На основе фотографии т/места, <i>$(fix_date)</i> была поставлена задача:<br/><br/>$(msg)<br/><br/>Автор: <b>$(u_name)</b>.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','targets','','shelf','Текущее выполнение цели по SOS (доля полки) - <b>$(sos)%</b>, необходимо увеличить представленность на полке.<br/><br/>Дата: $(fix_date).<br/>Автор: <b>$(u_name)</b>.');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','urgent','','audit','Устранение замечаний, выявленных в ходе аудита размещения продукции от $(fix_date) (автор: $(u_name)).');
insert into "L10n"(lang_id,obj_code,obj_id,obj_attr,str) values('ru','urgent','','target','Приоритетное выполнение задач, поставленных $(fix_date) (автор: $(u_name)).');
