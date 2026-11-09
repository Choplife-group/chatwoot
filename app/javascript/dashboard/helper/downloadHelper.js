import fromUnixTime from 'date-fns/fromUnixTime';
import format from 'date-fns/format';

export const downloadCsvFile = (fileName, content) => {
  const contentType = 'data:text/csv;charset=utf-8;';
  const blob = new Blob([content], { type: contentType });
  const url = URL.createObjectURL(blob);

  const link = document.createElement('a');
  link.setAttribute('download', fileName);
  link.setAttribute('href', url);
  link.click();
  return link;
};

// Saves a file the API sent back, under the name from its Content-Disposition header
export const downloadResponseFile = (response, fallbackName) => {
  const disposition = response.headers?.['content-disposition'] || '';
  const fileName = disposition.match(/filename="([^"]+)"/)?.[1] || fallbackName;
  const url = URL.createObjectURL(response.data);

  const link = document.createElement('a');
  link.setAttribute('download', fileName);
  link.setAttribute('href', url);
  link.click();
  URL.revokeObjectURL(url);
  return link;
};

export const generateFileName = ({ type, to, businessHours = false }) => {
  let name = `${type}-report-${format(fromUnixTime(to), 'dd-MM-yyyy')}`;
  if (businessHours) {
    name = `${name}-business-hours`;
  }
  return `${name}.csv`;
};
