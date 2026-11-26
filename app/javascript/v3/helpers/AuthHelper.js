import Cookies from 'js-cookie';
import { DEFAULT_REDIRECT_URL } from 'dashboard/constants/globals';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { accountLandingPath } from 'dashboard/helper/routeHelpers';

export const hasAuthCookie = () => {
  return !!Cookies.get('cw_d_session_info');
};

const getSSOAccount = ({ ssoAccountId, user }) => {
  const { accounts = [], account_id = null } = user || {};
  const ssoAccount = accounts.find(
    account => account.id === Number(ssoAccountId)
  );
  if (ssoAccount || !accounts.length) return ssoAccount;
  // If the account id is not found, redirect to the default account
  const accountId = account_id || accounts[0].id;
  return accounts.find(account => account.id === accountId) || accounts[0];
};

const capitalize = str =>
  str
    .split(/[._-]+/)
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');

export const getCredentialsFromEmail = email => {
  const [localPart, domain] = email.split('@');
  const namePart = localPart.split('+')[0];
  return {
    fullName: capitalize(namePart),
    accountName: capitalize(domain.split('.')[0]),
  };
};

export const getLoginRedirectURL = ({
  ssoAccountId,
  ssoConversationId,
  user,
}) => {
  const account = getSSOAccount({ ssoAccountId, user });
  if (!account) return DEFAULT_REDIRECT_URL;

  const accountPath = `accounts/${account.id}`;
  if (ssoConversationId) {
    return frontendURL(`${accountPath}/conversations/${ssoConversationId}`);
  }
  return frontendURL(`${accountPath}/${accountLandingPath(account)}`);
};
