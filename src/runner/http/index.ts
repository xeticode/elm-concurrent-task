// Http Task

export interface Request {
  url: string;
  method: string;
  headers: { name: string; value: string }[];
  expect: Expect;
  body: any;
}

export type Response = ResponseSuccess | ResponseError;
export type Expect = "STRING" | "JSON";

export interface ResponseSuccess {
  body: any;
  status: number;
  statusText: string;
}

export type HttpError =
  | "BAD_URL"
  | "NETWORK_ERROR"
  | "TIMEOUT"
  | "BAD_BODY"
  | string;

export interface ResponseError {
  error: HttpError;
  body?: any;
  status?: number;
  statusText?: string;
}

export function toHeaders(request: Request): { [header: string]: string } {
  return Object.fromEntries(
    request.headers.map((header) => [header.name, header.value])
  );
}